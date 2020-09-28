from tools.pip_import.metadata import PackageMetadata, PyProject, RequirementSet, SetupConfig


class DependencyMetadata:
    def __init__(self, requirements=None, build_requirements=None, extras=None):
        self.requirements = requirements
        self.build_requirements = build_requirements
        self.extras = extras

    def __repr__(self):
        return repr(self.requirements)

    @staticmethod
    def merge(*items):
        def _merge(a, b):
            return DependencyMetadata(
                requirements=b.requirements or a.requirements or [],
                build_requirements=b.build_requirements or a.build_requirements or [],
                extras=b.extras or a.extras or [],
            )

        result = DependencyMetadata()

        for item in items:
            result = _merge(result, item)

        return result


class Distribution(object):
    def __init__(self, pkg, project_name, version):
        self.pkg = pkg
        self.project_name = project_name
        self.version = version

    def __enter__(self):
        self.pkg.open()
        return self

    def __exit__(self, type, value, tb):
        self.pkg.close()

    def load(self, paths, **kwargs):
        for path in paths:
            result = self.pkg.read_if_exists(path, **kwargs)

            if result != None:
                return result

        return None

    def base_path(self, path):
        return path

    def dependencies(self):
        return DependencyMetadata()


class EggDistribution(Distribution):
    def __init__(self, pkg, project_name, version):
        super(EggDistribution, self).__init__(pkg, project_name, version)

    def base_path(self, path):
        return '%s-%s/%s' % (self.project_name, self.version, path)

    def egg_info_path(self, path):
        return self.base_path('%s.egg-info/%s' % (self.project_name, path))

    def pkg_info(self):
        return self.pkg.read_if_exists(
            self.egg_info_path('PKG-INFO'),
            loader=PackageMetadata,
        )

    def requires(self):
        return self.pkg.read_if_exists(
            self.egg_info_path('requires.txt'),
            loader=RequirementSet,
        )

    def setup_requires(self):
        return self.pkg.read_if_exists(
            self.egg_info_path('setup_requires.txt'),
            loader=RequirementSet,
        )

    def dependencies(self):
        deps = [super(EggDistribution, self).dependencies()]

        pkginfo = self.pkg_info()
        requires = self.requires()
        setup_requires = self.setup_requires()

        if pkginfo != None:
            deps.append(DependencyMetadata(
                requirements=RequirementSet.parse(pkginfo.requires_dist),
                extras=pkginfo.provides_extras,
            ))

        if requires != None:
            deps.append(DependencyMetadata(
                requirements=requires,
            ))

        if setup_requires != None:
            deps.append(DependencyMetadata(
                build_requirements=setup_requires,
            ))

        return DependencyMetadata.merge(*deps)


class SourceDistribution(EggDistribution):
    def __init__(self, pkg, project_name, version):
        super(SourceDistribution, self).__init__(pkg, project_name, version)

    def pkg_info(self):
        pkg_info = super(SourceDistribution, self).pkg_info()

        if pkg_info != None:
            pkg_info = self.pkg.read_if_exists(
                self.base_path('PKG-INFO'),
                loader=PackageMetadata,
            )

        return pkg_info

    def setup_cfg(self):
        return self.pkg.read_if_exists(
            self.base_path('setup.cfg'),
            loader=SetupConfig,
        )

    def pyproject(self):
        return self.pkg.read_if_exists(
            self.base_path('pyproject.toml'),
            loader=PyProject,
        )

    def dependencies(self):
        deps = [super(SourceDistribution, self).dependencies()]

        setupcfg = self.setup_cfg()
        pyproject = self.pyproject()

        if setupcfg:
            requires = setupcfg._data.get(
                'metadata', {}).get('requires-dist', [])

            deps.append(DependencyMetadata(
                requirements=RequirementSet.parse(requires),
            ))

            requires = setupcfg._data.get(
                'options', {}).get('install_requires', [])

            deps.append(DependencyMetadata(
                requirements=RequirementSet.parse(requires),
            ))

        if pyproject:
            requires = pyproject.build_system().get('requires', [])

            deps.append(DependencyMetadata(
                build_requirements=RequirementSet.parse(requires),
            ))

        return DependencyMetadata.merge(*deps)


class WheelDistribution(Distribution):
    def __init__(self, pkg, project_name, version):
        super(WheelDistribution, self).__init__(pkg, project_name, version)

    def dist_info_path(self, path):
        return self.base_path('%s-%s.dist-info/%s' % (self.project_name, self.version, path))

    def dist_info_metadata(self):
        return self.pkg.read_if_exists(
            self.dist_info_path('METADATA'),
            loader=PackageMetadata,
        )

    def dependencies(self):
        deps = [super(WheelDistribution, self).dependencies()]

        pkginfo = self.dist_info_metadata()

        if pkginfo != None:
            deps.append(DependencyMetadata(
                requirements=RequirementSet.parse(pkginfo.requires_dist),
                extras=pkginfo.provides_extras,
            ))

        return DependencyMetadata.merge(*deps)
