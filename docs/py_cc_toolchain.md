<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Implementation of py_cc_toolchain rule.

NOTE: This is a beta-quality feature. APIs subject to change until
https://github.com/bazelbuild/rules_python/issues/824 is considered done.


<a id="py_cc_toolchain"></a>

## py_cc_toolchain

<pre>
py_cc_toolchain(<a href="#py_cc_toolchain-name">name</a>, <a href="#py_cc_toolchain-headers">headers</a>, <a href="#py_cc_toolchain-python_version">python_version</a>)
</pre>

A toolchain for a Python runtime's C/C++ information (e.g. headers)

This rule carries information about the C/C++ side of a Python runtime, e.g.
headers, shared libraries, etc.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="py_cc_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="py_cc_toolchain-headers"></a>headers |  Target that provides the Python headers. Typically this is a cc_library target.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="py_cc_toolchain-python_version"></a>python_version |  The Major.minor Python version, e.g. 3.11   | String | required |  |


