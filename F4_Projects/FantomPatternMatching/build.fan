using build

class Build : build::BuildPod
{
  new make()
  {
    podName = "fantomPatternMatching"
    summary = ""
    srcDirs = [`src/`]
    depends = ["sys 1.0", "build 1.0", "compiler_new 1.0"]
  }
}
