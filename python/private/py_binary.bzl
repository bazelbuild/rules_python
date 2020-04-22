"""
Copyright 2018 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

"""
/** Common implementation logic for {@code py_binary} and {@code py_test}. */
public abstract class PyExecutable implements RuleConfiguredTargetFactory {
"""

def _py_binary_impl(ctx):
    """
    // Init the make variable context first. Otherwise it may be incorrectly initialized by default
    // inside semantics/common via {@link RuleContext#getExpander}.
    ruleContext.initConfigurationMakeVariableContext(new CcFlagsSupplier(ruleContext));

    PythonSemantics semantics = createSemantics();
    PyCommon common = new PyCommon(ruleContext, semantics);

    List<Artifact> srcs = common.validateSrcs();
    List<Artifact> allOutputs =
        new ArrayList<>(semantics.precompiledPythonFiles(ruleContext, srcs, common));
    if (ruleContext.hasErrors()) {
      return null;
    }

    common.initBinary(allOutputs);
    semantics.validate(ruleContext, common);
    if (ruleContext.hasErrors()) {
      return null;
    }

    CcInfo ccInfo =
        semantics.buildCcInfoProvider(ruleContext.getPrerequisites("deps", TransitionMode.TARGET));

    Runfiles commonRunfiles = collectCommonRunfiles(ruleContext, common, semantics, ccInfo);

    Runfiles.Builder defaultRunfilesBuilder = new Runfiles.Builder(
        ruleContext.getWorkspaceName(), ruleContext.getConfiguration().legacyExternalRunfiles())
        .merge(commonRunfiles);
    semantics.collectDefaultRunfilesForBinary(ruleContext, common, defaultRunfilesBuilder);

    common.createExecutable(ccInfo, defaultRunfilesBuilder);

    Runfiles defaultRunfiles = defaultRunfilesBuilder.build();

    RunfilesSupport runfilesSupport =
        RunfilesSupport.withExecutable(
            ruleContext,
            defaultRunfiles,
            common.getExecutable());

    if (ruleContext.hasErrors()) {
      return null;
    }

    Runfiles dataRunfiles;
    if (ruleContext.getFragment(PythonConfiguration.class).buildTransitiveRunfilesTrees()) {
      // Only include common runfiles and middleman. Default runfiles added by semantics are
      // excluded. The middleman is necessary to ensure the runfiles trees are generated for all
      // dependency binaries.
      dataRunfiles =
          new Runfiles.Builder(
                  ruleContext.getWorkspaceName(),
                  ruleContext.getConfiguration().legacyExternalRunfiles())
              .merge(commonRunfiles)
              .addLegacyExtraMiddleman(runfilesSupport.getRunfilesMiddleman())
              .build();
    } else {
      dataRunfiles = commonRunfiles;
    }

    RunfilesProvider runfilesProvider = RunfilesProvider.withData(defaultRunfiles, dataRunfiles);

    RuleConfiguredTargetBuilder builder =
        new RuleConfiguredTargetBuilder(ruleContext);
    common.addCommonTransitiveInfoProviders(builder, common.getFilesToBuild());

    semantics.postInitExecutable(ruleContext, runfilesSupport, common, builder);

    return builder
        .setFilesToBuild(common.getFilesToBuild())
        .add(RunfilesProvider.class, runfilesProvider)
        .setRunfilesSupport(runfilesSupport, common.getExecutable())
        .addNativeDeclaredProvider(new PyCcLinkParamsProvider(ccInfo))
        .build();
    """

    "PYTHONPATH"

PYTHON_SOURCE = [".py"]

PROVIDER_NAME = "py"

LegacyProvider = provider(PROVIDER_NAME)


_py_binary = rule(
    implementation = _py_binary_impl,
    doc = """
<p>
  A <code>py_binary</code> is an executable Python program consisting
  of a collection of <code>.py</code> source files (possibly belonging
  to other <code>py_library</code> rules), a <code>*.runfiles</code>
  directory tree containing all the code and data needed by the
  program at run-time, and a stub script that starts up the program with
  the correct initial environment and data.
</p>

<h4 id="py_binary_examples">Examples</h4>

<pre class="code">
py_binary(
    name = "foo",
    srcs = ["foo.py"],
    data = [":transform"],  # a cc_binary which we invoke at run time
    deps = [
        "//pyglib",
        ":foolib",  # a py_library
    ],
)
</pre>

<p>If you want to run a <code>py_binary</code> from within another binary or
   test (for example, running a python binary to set up some mock resource from
   within a java_test) then the correct approach is to make the other binary or
   test depend on the <code>py_binary</code> in its data section. The other
   binary can then locate the <code>py_binary</code> relative to the source
   directory.
</p>

<pre class="code">
py_binary(
    name = "test_main",
    srcs = ["test_main.py"],
    deps = [":testlib"],
)

java_library(
    name = "testing",
    srcs = glob(["*.java"]),
    data = [":test_main"]
)
</pre>
    """,
    attrs = {
        "name": attr.string(
            doc = "A unique name for this target.\n\n" + 
"If main is unspecified, this should be the same as the name of the source file that is the main entry point of the application, minus the extension. " +
"For example, if your entry point is called main.py, then your name should be main.",
        ),
        "deps": attr.label_list(
            providers = [
                # Legacy provider.
                # TODO(b/153363654): Remove this legacy set.
                LegacyProvider,
                # Modern provider.
                PyInfo,
            ],
            doc = """The list of other libraries to be linked in to the binary target.
          See general comments about <code>deps</code> at
          <a href="${link common-definitions#common-attributes}">
          Attributes common to all build rules</a>.
          These are generally
          <a href="${link py_library}"><code>py_library</code></a> rules.
            """
        ),
        "srcs": attr.label_list(allowed_files = PYTHON_SOURCE, mandatory = True,
            doc = """The list of source (<code>.py</code>) files that are processed to create the target.
          This includes all your checked-in code and any generated source files. Library targets
          belong in <code>deps</code> instead, while other binary files needed at runtime belong in
          <code>data</code>.""",
        ),
        "imports": attr.string_list(default = [],
            doc = """List of import directories to be added to the <code>PYTHONPATH</code>.
          <p>
          Subject to <a href="${link make-variables}">"Make variable"</a> substitution. These import
          directories will be added for this rule and all rules that depend on it (note: not the
          rules this rule depends on. Each directory will be added to <code>PYTHONPATH</code> by
          <a href="${link py_binary}"><code>py_binary</code></a> rules that depend on this rule.
          </p>
          <p>
          Absolute paths (paths that start with <code>/</code>) and paths that references a path
          above the execution root are not allowed and will result in an error.
          </p>""",
        ),
        "legacy_create_init": attr.int(default = -1,
            doc = """Whether to implicitly create empty __init__.py files in the runfiles tree.
          These are created in every directory containing Python source code or
          shared libraries, and every parent directory of those directories, excluding the repo root
          directory. The default, auto, means true unless
          <code>--incompatible_default_to_explicit_init_py</code> is used. If false, the user is
          responsible for creating (possibly empty) __init__.py files and adding them to the
          <code>srcs</code> of Python targets as required.""",
        ),
        "python_version": attr.string(
            doc = """Whether to build this target (and its transitive <code>deps</code>) for Python 2 or Python
          3. Valid values are <code>"PY2"</code> and <code>"PY3"</code> (the default).

          <p>The Python version is always reset (possibly by default) to whatever version is
          specified by this attribute, regardless of the version specified on the command line or by
          other higher targets that depend on this one.

          <p>If you want to <code>select()</code> on the current Python version, you can inspect the
          value of <code>@rules_python//python:python_version</code>. See
          <a href="https://github.com/bazelbuild/rules_python/blob/120590e2f2b66e5590bf4dc8ebef9c5338984775/python/BUILD#L43">here</a>
          for more information.

          <p><b>Bug warning:</b> This attribute sets the version for which Bazel builds your target,
          but due to <a href="https://github.com/bazelbuild/bazel/issues/4815">#4815</a>, the
          resulting stub script may still invoke the wrong interpreter version at runtime. See
          <a href="https://github.com/bazelbuild/bazel/issues/4815#issuecomment-460777113">this
          workaround</a>, which involves defining a <code>py_runtime</code> target that points to
          either Python version as needed, and activating this <code>py_runtime</code> by setting
          <code>--python_top</code>.""",
        ),
        "srcs_version": attr.string(default = PythonVersion.DEFAULT_SRCS_VALUE.toString(), values = PythonVersion.SRCS_STRINGS,
            doc = """This attribute declares the target's <code>srcs</code> to be compatible with either Python
          2, Python 3, or both. To actually set the Python runtime version, use the
          <a href="${link py_binary.python_version}"><code>python_version</code></a> attribute of an
          executable Python rule (<code>py_binary</code> or <code>py_test</code>).

          <p>Allowed values are: <code>"PY2AND3"</code>, <code>"PY2"</code>, and <code>"PY3"</code>.
          The values <code>"PY2ONLY"</code> and <code>"PY3ONLY"</code> are also allowed for historic
          reasons, but they are essentially the same as <code>"PY2"</code> and <code>"PY3"</code>
          and should be avoided.

          <p>Note that only the executable rules ({@code py_binary} and {@code py_library}) actually
          verify the current Python version against the value of this attribute. (This is a feature;
          since {@code py_library} does not change the current Python version, if it did the
          validation, it'd be impossible to build both {@code PY2ONLY} and {@code PY3ONLY} libraries
          in the same invocation.) Furthermore, if there is a version mismatch, the error is only
          reported in the execution phase. In particular, the error will not appear in a {@code
          bazel build --nobuild} invocation.)

          <p>To get diagnostic information about which dependencies introduce version requirements,
          you can run the <code>find_requirements</code> aspect on your target:
          <pre>
          bazel build &lt;your target&gt; \
              --aspects=@rules_python//python:defs.bzl%find_requirements \
              --output_groups=pyversioninfo
          </pre>
          This will build a file with the suffix <code>-pyversioninfo.txt</code> giving information
          about why your target requires one Python version or another. Note that it works even if
          the given target failed to build due to a version conflict."
        )""",
        "main": attr.string(
            doc = """The name of the source file that is the main entry point of the application.
          This file must also be listed in <code>srcs</code>. If left unspecified,
          <code>name</code> is used instead (see above). If <code>name</code> does not
          match any filename in <code>srcs</code>, <code>main</code> must be specified."""
        ),
        "stamp": attr.int(default = -1,
            doc = """Enable link stamping.
          Whether to encode build information into the binary. Possible values:
          <ul>
            <li><code>stamp = 1</code>: Stamp the build information into the
              binary. Stamped binaries are only rebuilt when their dependencies
              change. Use this if there are tests that depend on the build
              information.</li>
            <li><code>stamp = 0</code>: Always replace build information by constant
              values. This gives good build result caching.</li>
            <li><code>stamp = -1</code>: Embedding of build information is controlled
              by the <a href="../user-manual.html#flag--stamp">--[no]stamp</a> Blaze
              flag.</li>
          </ul>
            """,
        ),
        # do not depend on lib2to3:2to3 rule, because it creates circular dependencies
        # 2to3 is itself written in Python and depends on many libraries.
        "_python2to3": attr.label(default = "@io_bazel//tools/python:2to3", cfg = "host")
        "_zipper": attr.label(default = "@io_bazel//tools/zip:zipper"),
        "_launcher": attr.label(default = "@io_bazel//tools/launcher:launcher"),
    },
)

def py_binary(name, args*, main = None, kwargs**):

    if main == None:
        main = name[:-3] # strip .py

    return _py_binary(name, *args, default, **kwargs)

"""
  /**
   * Creates a pluggable semantics object to be used for the analysis of a target of this rule type.
   */
  protected abstract PythonSemantics createSemantics();
"""

"""
  @Override
  public ConfiguredTarget create(RuleContext ruleContext)
      throws InterruptedException, RuleErrorException, ActionConflictException {
    
  }

  /**
   * If requested, creates empty __init__.py files for each manifest file.
   *
   * <p>We do this if the rule defines {@code legacy_create_init} and its value is true. Auto is
   * treated as false iff {@code --incompatible_default_to_explicit_init_py} is given.
   *
   * <p>See {@link PythonUtils#getInitPyFiles} for details about how the files are created.
   */
  private static void maybeCreateInitFiles(RuleContext ruleContext, Runfiles.Builder builder) {
    boolean createFiles;
    if (!ruleContext.attributes().has("legacy_create_init", BuildType.TRISTATE)) {
      createFiles = true;
    } else {
      TriState legacy = ruleContext.attributes().get("legacy_create_init", BuildType.TRISTATE);
      if (legacy == TriState.AUTO) {
        createFiles = !ruleContext.getFragment(PythonConfiguration.class).defaultToExplicitInitPy();
      } else {
        createFiles = legacy != TriState.NO;
      }
    }
    if (createFiles) {
      builder.setEmptyFilesSupplier(PythonUtils.GET_INIT_PY_FILES);
    }
  }

  private static Runfiles collectCommonRunfiles(
      RuleContext ruleContext, PyCommon common, PythonSemantics semantics, CcInfo ccInfo)
      throws InterruptedException, RuleErrorException {
    Runfiles.Builder builder = new Runfiles.Builder(
        ruleContext.getWorkspaceName(), ruleContext.getConfiguration().legacyExternalRunfiles());
    builder.addArtifact(common.getExecutable());
    if (common.getConvertedFiles() != null) {
      builder.addSymlinks(common.getConvertedFiles());
    } else {
      builder.addTransitiveArtifacts(common.getFilesToBuild());
    }
    semantics.collectDefaultRunfiles(ruleContext, builder);
    builder.add(ruleContext, PythonRunfilesProvider.TO_RUNFILES);

    maybeCreateInitFiles(ruleContext, builder);

    semantics.collectRunfilesForBinary(ruleContext, builder, common, ccInfo);
    return builder.build();
  }
}
"""
