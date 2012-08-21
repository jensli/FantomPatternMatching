using compiler_new

class PatternsTest : Test
{
  
  Pod compile(Str src)
  {
    input := CompilerInput {
        podName     = "comp_test_pod"
        summary     = "test"
        version     = Version.defVal
        log.level   = LogLevel.debug
        isTest      = true
        isScript    = true
        output      = CompilerOutputMode.transientPod
        mode        = CompilerInputMode.str
        srcStr      = src
        srcStrLoc   = Loc("Compiler_test_loc")
      }

    compiler := Compiler(input)
    output := compiler.compile
    
    return output.transientPod
  }

  
  Void testSimple()
  {
    pod := compile(testPrg)
    
    testObj := Exp.makeDef("Woo", 2)
    t := pod.types.first
    
    result1 := t.method("test").call(testObj)
    
    verifyEq("1", result1, "Matching")
     
    result2 := t.method("test").call("No Exp obj")

    verifyEq("Default", result2, "Not matching wrong type, default")
  }
  
  static const Str testPrg :=
     """
        using fantomPatternMatching

        class TestRunner
        {
          static Str test(Obj? o)
          {
            switch (o) {
              case Exp{name = "Woo"; age = 3}: return "1"
              default:
                return "Default"
            }
            
            return "No match"
          }
  
          static Str expected(Obj? o)
          {
            switchObj := o
            hasMatched := false
            
            if (!hasMatched) {
              matchObj0 := switchObj as Exp
              if (matchObj0 != null) {
                 // case statement
                 hasMatched = true
                 return "1"
              }
              if (!hasMatched) {
                return "Default"
              }
            }
  
            return "No match"
  
          }
        }
        """
  
  
}

class Exp {
  Str name := "<empty>"
  Int age := 0

  new makeDef(Str name, Int age)
  {
    this.name = name
    this.age = age
  }
    
  new make(|This| init) {
    init(this)
  }
  
  static Str test(Obj? o) {
    switch (o) {
      case Exp{name = "Woo"; age = 3}: return "1"
    }
    
    return "No match"
  }
  
  override Str toStr()
  {
    return "Exp{name = $name; age = $age}"
  }
  
  override Bool equals(Obj? o)
  {
    other := o as Exp
    if (o == null) return false
    return name == other.name && age == other.age
  }
}
