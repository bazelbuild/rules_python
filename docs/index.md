
# Overview


<nav class="toc">
  <h2>Rule sets</h2>
  <ul>
    <li><a href="#pip">Import pip requirements into Bazel.</a></li>
    <li><a href="#python">python Rules</a></li>
    <li><a href="#whl">Import .whl files into Bazel.</a></li>
  </ul>
</nav>

<h2><a href="./python/pip.html">Import pip requirements into Bazel.</a></h2>

<h3>Macros</h3>
<table class="overview-table">
  <colgroup>
    <col class="col-name" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr>
      <td>
        <a href="./python/pip.html#pip_repositories">
          <code>pip_repositories</code>
        </a>
      </td>
      <td>
        <p>Pull in dependencies needed for pulling in pip dependencies.</p>

      </td>
    </tr>
  </tbody>
</table>
<h3>Repository Rules</h3>
<table class="overview-table">
  <colgroup>
    <col class="col-name" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr>
      <td>
        <a href="./python/pip.html#pip3_import">
          <code>pip3_import</code>
        </a>
      </td>
      <td>
        <p>A rule for importing &lt;code&gt;requirements.txt&lt;/code&gt; dependencies into Bazel.</p>

      </td>
    </tr>
    <tr>
      <td>
        <a href="./python/pip.html#pip_import">
          <code>pip_import</code>
        </a>
      </td>
      <td>
        <p>A rule for importing &lt;code&gt;requirements.txt&lt;/code&gt; dependencies into Bazel.</p>

      </td>
    </tr>
  </tbody>
</table>
<h2><a href="./python/python.html">python Rules</a></h2>

<h3>Macros</h3>
<table class="overview-table">
  <colgroup>
    <col class="col-name" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr>
      <td>
        <a href="./python/python.html#py_library">
          <code>py_library</code>
        </a>
      </td>
      <td>
        <p>See the Bazel core py_library documentation.</p>

      </td>
    </tr>
    <tr>
      <td>
        <a href="./python/python.html#py_binary">
          <code>py_binary</code>
        </a>
      </td>
      <td>
        <p>See the Bazel core py_binary documentation.</p>

      </td>
    </tr>
    <tr>
      <td>
        <a href="./python/python.html#py_test">
          <code>py_test</code>
        </a>
      </td>
      <td>
        <p>See the Bazel core py_test documentation.</p>

      </td>
    </tr>
  </tbody>
</table>
<h2><a href="./python/whl.html">Import .whl files into Bazel.</a></h2>

<h3>Repository Rules</h3>
<table class="overview-table">
  <colgroup>
    <col class="col-name" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr>
      <td>
        <a href="./python/whl.html#whl_library">
          <code>whl_library</code>
        </a>
      </td>
      <td>
        <p>A rule for importing &lt;code&gt;.whl&lt;/code&gt; dependencies into Bazel.</p>

      </td>
    </tr>
  </tbody>
</table>
