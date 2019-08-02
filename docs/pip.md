<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#pip_import"></a>

## pip_import

<pre>
pip_import(<a href="#pip_import-name">name</a>, <a href="#pip_import-requirements">requirements</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="pip_import-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this repository.
        </p>
      </td>
    </tr>
    <tr id="pip_import-requirements">
      <td><code>requirements</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
      </td>
    </tr>
  </tbody>
</table>


<a name="#pip_repositories"></a>

## pip_repositories

<pre>
pip_repositories()
</pre>

Pull in dependencies needed to use the packaging rules.



