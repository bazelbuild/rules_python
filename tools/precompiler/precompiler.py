# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""A simple precompiler to generate deterministic pyc files for Bazel."""

import argparse
import asyncio
import itertools
import json
import logging
import os.path
import py_compile
import sys
import traceback

_logger = logging.getLogger("precompiler")


def _create_parser():
    parser = argparse.ArgumentParser(fromfile_prefix_chars="@")
    parser.add_argument("--invalidation_mode")
    parser.add_argument("--optimize", type=int)
    parser.add_argument("--python_version")

    parser.add_argument("--src", action="append", dest="srcs")
    parser.add_argument("--src_name", action="append", dest="src_names")
    parser.add_argument("--pyc", action="append", dest="pycs")

    parser.add_argument("--persistent_worker", action="store_true")
    parser.add_argument("--log_level", default="ERROR")
    parser.add_argument("--worker_impl", default="async")
    return parser


def _compile(options):
    try:
        invalidation_mode = getattr(
            py_compile.PycInvalidationMode, options.invalidation_mode.upper()
        )
    except AttributeError as e:
        raise ValueError(
            f"Unknown PycInvalidationMode: {options.invalidation_mode}"
        ) from e

    if len(options.srcs) != len(options.src_names) != len(options.pycs):
        raise AssertionError(
            "Mismatched number of --src, --src_name, and/or --pyc args"
        )

    for src, src_name, pyc in zip(options.srcs, options.src_names, options.pycs):
        _logger.info(
            "precompiling: src=%s, optimize=%s, invalidation=%s",
            src,
            options.optimize,
            invalidation_mode,
        )
        py_compile.compile(
            src,
            pyc,
            doraise=True,
            dfile=src_name,
            optimize=options.optimize,
            invalidation_mode=invalidation_mode,
        )
    return 0


class _SerialPersistentWorker:
    """Simple, synchronous, serial persistent worker."""

    def __init__(self, instream, outstream):
        self._instream = instream
        self._outstream = outstream
        self._parser = _create_parser()

    def run(self):
        try:
            while True:
                request = None
                try:
                    request = self._get_next_request()
                    if request is None:
                        _logger.info("Empty request: exiting")
                        break
                    response = self._process_request(request)
                    if response:  # May be none for cancel request
                        self._send_response(response)
                except Exception:
                    _logger.exception("Unhandled error: request=%s", request)
                    output = (
                        f"Unhandled error:\nRequest: {request}\n"
                        + traceback.format_exc()
                    )
                    request_id = 0 if not request else request.get("requestId", 0)
                    self._send_response(
                        {
                            "exitCode": 3,
                            "output": output,
                            "requestId": request_id,
                        }
                    )
        finally:
            _logger.info("Worker shutting down")

    def _get_next_request(self):
        line = self._instream.readline()
        if not line:
            return None
        return json.loads(line)

    def _process_request(self, request):
        if request.get("cancel"):
            return None
        options = self._options_from_request(request)
        _compile(options)
        response = {
            "requestId": request.get("requestId", 0),
            "exitCode": 0,
        }
        return response

    def _options_from_request(self, request):
        options = self._parser.parse_args(request["arguments"])
        if request.get("sandboxDir"):
            prefix = request["sandboxDir"]
            options.srcs = [os.path.join(prefix, v) for v in options.srcs]
            options.pycs = [os.path.join(prefix, v) for v in options.pycs]
        return options

    def _send_response(self, response):
        self._outstream.write(json.dumps(response) + "\n")
        self._outstream.flush()


class _AsyncPersistentWorker:
    """Asynchronous, concurrent, persistent worker."""

    def __init__(self, reader, writer):
        self._reader = reader
        self._writer = writer
        self._parser = _create_parser()
        self._request_id_to_task = {}
        self._task_to_request_id = {}

    @classmethod
    async def main(cls, instream, outstream):
        reader, writer = await cls._connect_streams(instream, outstream)
        await cls(reader, writer).run()

    @classmethod
    async def _connect_streams(cls, instream, outstream):
        loop = asyncio.get_event_loop()
        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await loop.connect_read_pipe(lambda: protocol, instream)

        w_transport, w_protocol = await loop.connect_write_pipe(
            asyncio.streams.FlowControlMixin, outstream
        )
        writer = asyncio.StreamWriter(w_transport, w_protocol, reader, loop)
        return reader, writer

    async def run(self):
        while True:
            _logger.info("pending requests: %s", len(self._request_id_to_task))
            request = await self._get_next_request()
            request_id = request.get("requestId", 0)
            task = asyncio.create_task(
                self._process_request(request), name=f"request_{request_id}"
            )
            self._request_id_to_task[request_id] = task
            self._task_to_request_id[task] = request_id
            task.add_done_callback(self._handle_task_done)

    async def _get_next_request(self):
        _logger.debug("awaiting line")
        line = await self._reader.readline()
        _logger.debug("recv line: %s", line)
        return json.loads(line)

    def _handle_task_done(self, task):
        request_id = self._task_to_request_id[task]
        _logger.info("task done: %s %s", request_id, task)
        del self._task_to_request_id[task]
        del self._request_id_to_task[request_id]

    async def _process_request(self, request):
        _logger.info("request %s: start: %s", request.get("requestId"), request)
        try:
            if request.get("cancel", False):
                await self._process_cancel_request(request)
            else:
                await self._process_compile_request(request)
        except asyncio.CancelledError:
            _logger.info(
                "request %s: cancel received, stopping processing",
                request.get("requestId"),
            )
            # We don't send a response because we assume the request that
            # triggered cancelling sent the response
            raise
        except:
            _logger.exception("Unhandled error: request=%s", request)
            self._send_response(
                {
                    "exitCode": 3,
                    "output": f"Unhandled error:\nRequest: {request}\n"
                    + traceback.format_exc(),
                    "requestId": 0 if not request else request.get("requestId", 0),
                }
            )

    async def _process_cancel_request(self, request):
        request_id = request.get("requestId", 0)
        task = self._request_id_to_task.get(request_id)
        if not task:
            # It must be already completed, so ignore the request, per spec
            return

        task.cancel()
        self._send_response({"requestId": request_id, "wasCancelled": True})

    async def _process_compile_request(self, request):
        options = self._options_from_request(request)
        # _compile performs a varity of blocking IO calls, so run it separately
        await asyncio.to_thread(_compile, options)
        self._send_response(
            {
                "requestId": request.get("requestId", 0),
                "exitCode": 0,
            }
        )

    def _options_from_request(self, request):
        options = self._parser.parse_args(request["arguments"])
        if request.get("sandboxDir"):
            prefix = request["sandboxDir"]
            options.srcs = [os.path.join(prefix, v) for v in options.srcs]
            options.pycs = [os.path.join(prefix, v) for v in options.pycs]
        return options

    def _send_response(self, response):
        _logger.info("request %s: respond: %s", response.get("requestId"), response)
        self._writer.write(json.dumps(response).encode("utf8") + b"\n")


def main(args):
    options = _create_parser().parse_args(args)

    if options.persistent_worker:
        # Only configure logging for workers. This prevents non-worker
        # invocations from spamming stderr with logging info
        logging.basicConfig(level=getattr(logging, options.log_level))
        _logger.info("persistent worker: impl=%s", options.worker_impl)
        if options.worker_impl == "serial":
            _SerialPersistentWorker(sys.stdin, sys.stdout).run()
        elif options.worker_impl == "async":
            asyncio.run(_AsyncPersistentWorker.main(sys.stdin, sys.stdout))
        else:
            raise ValueError(f"Unknown worker impl: {options.worker_impl}")
    else:
        _compile(options)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
