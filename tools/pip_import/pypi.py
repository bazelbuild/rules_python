import os
import hashlib
import shutil
import tempfile
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from cachecontrol import CacheControlAdapter
from cachecontrol.caches.file_cache import FileCache


def _hash_file(filename):
    h = hashlib.sha256()

    with open(filename, 'rb') as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            h.update(byte_block)

    return h.hexdigest()


def _atomic_file_from_stream(res, output):
    fd, path = tempfile.mkstemp()

    with os.fdopen(fd, 'wb') as f:
        for chunk in res.iter_content(chunk_size=4096):
            f.write(chunk)

        os.fsync(f.fileno())
        os.rename(path, output)


class PypiAPI:
    def __init__(self, base_url="https://pypi.python.org/pypi", cache_dir='/tmp/pip_import'):
        retry_strategy = Retry(
            total=3,
            status_forcelist=[429, 500, 502, 503, 504],
            method_whitelist=["HEAD", "GET", "OPTIONS"]
        )

        cache = FileCache(os.path.join(cache_dir, '.web_cache'), forever=True)

        adapter = HTTPAdapter(max_retries=retry_strategy)
        cached_adapter = CacheControlAdapter(
            cache=cache, max_retries=retry_strategy)

        session = requests.Session()
        session.mount(base_url, cached_adapter)
        session.mount('https://', adapter)

        self.client = session
        self.base_url = base_url
        self.cache_dir = cache_dir

    def get_project(self, project_name, version=None):
        url = "/" + project_name

        if version != None:
            url += "/" + version

        url += "/json"

        return self.client.get(self.base_url + url).json()

    def download_package(self, pkg, output_dir):
        filename = pkg['filename']
        digest = pkg['digests']['sha256']
        cache = os.path.join(self.cache_dir, digest)
        output = cache

        if os.path.isfile(cache):
            print("Downloading %s (cached)" % filename)
        else:
            print("Downloading %s" % filename)

            try:
                os.makedirs(os.path.dirname(cache))
            except:
                pass

            with requests.get(pkg['url'], stream=True) as res:
                _atomic_file_from_stream(res, cache)

        actual_digest = _hash_file(cache)

        if digest.lower() != actual_digest.lower():
            raise Exception(
                "digest mismatch: actual = %s, expected = %s", actual_digest, digest)

        if output_dir:
            output = os.path.join(output_dir, pkg['filename'])
            shutil.copyfile(cache, output)

        return output
