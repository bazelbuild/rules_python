<!-- Generated with Stardoc: http://skydoc.bazel.build -->


A macro to generate an entry_point from reading the 'console_scripts'.


<a id="entry_point"></a>

## entry_point

<pre>
entry_point(<a href="#entry_point-name">name</a>, <a href="#entry_point-pkg">pkg</a>, <a href="#entry_point-script">script</a>, <a href="#entry_point-deps">deps</a>, <a href="#entry_point-main">main</a>, <a href="#entry_point-kwargs">kwargs</a>)
</pre>

Generate an entry_point for a given package

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="entry_point-name"></a>name |  The name of the resultant py_binary target.   |  none |
| <a id="entry_point-pkg"></a>pkg |  The package for which to generate the script.   |  none |
| <a id="entry_point-script"></a>script |  The console script that the entry_point is going to be generated. Mandatory if there are more than 1 console_script in the package.   |  <code>None</code> |
| <a id="entry_point-deps"></a>deps |  The extra dependencies to add to the py_binary rule.   |  <code>None</code> |
| <a id="entry_point-main"></a>main |  The file to be written by the templating engine. Defaults to <code>rules_python_entry_point_{name}.py</code>.   |  <code>None</code> |
| <a id="entry_point-kwargs"></a>kwargs |  Extra parameters forwarded to py_binary.   |  none |


