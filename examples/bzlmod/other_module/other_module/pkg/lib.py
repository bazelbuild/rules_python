from python.runfiles import runfiles


def GetRunfilePathWithCurrentRepository():
    r = runfiles.Create()
    own_repo = r.CurrentRepository()
    # For a non-main repository, the name of the runfiles directory is equal to
    # the canonical repository name.
    return r.Rlocation(own_repo + "/other_module/pkg/data/data.txt")


def GetRunfilePathWithRepoMapping():
    return runfiles.Create().Rlocation("other_module/other_module/pkg/data/data.txt")
