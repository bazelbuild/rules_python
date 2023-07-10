<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Provider for C/C++ information about the Python runtime.

NOTE: This is a beta-quality feature. APIs subject to change until
https://github.com/bazelbuild/rules_python/issues/824 is considered done.


<a id="PyCcToolchainInfo"></a>

## PyCcToolchainInfo

<pre>
PyCcToolchainInfo(<a href="#PyCcToolchainInfo-headers">headers</a>, <a href="#PyCcToolchainInfo-python_version">python_version</a>)
</pre>

C/C++ information about the Python runtime.

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="PyCcToolchainInfo-headers"></a>headers |  (struct) Information about the header files, with fields:   * providers_map: a dict of string to provider instances. The key should be     a fully qualified name (e.g. <code>@rules_foo//bar:baz.bzl#MyInfo</code>) of the     provider to uniquely identify its type.<br><br>    The following keys are always present:       * CcInfo: the CcInfo provider instance for the headers.       * DefaultInfo: the DefaultInfo provider instance for the headers.<br><br>    A map is used to allow additional providers from the originating headers     target (typically a <code>cc_library</code>) to be propagated to consumers (directly     exposing a Target object can cause memory issues and is an anti-pattern).<br><br>    When consuming this map, it's suggested to use <code>providers_map.values()</code> to     return all providers; or copy the map and filter out or replace keys as     appropriate. Note that any keys begining with <code>_</code> (underscore) are     considered private and should be forward along as-is (this better allows     e.g. <code>:current_py_cc_headers</code> to act as the underlying headers target it     represents).    |
| <a id="PyCcToolchainInfo-python_version"></a>python_version |  (str) The Python Major.Minor version.    |


