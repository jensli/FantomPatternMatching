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
    
    t := pod.types.first
    
    verifyEq("1", 
      t.method("test").call(Exp("Woo", 3)),
      "Matching")
     
    verifyEq("Default", 
       t.method("test").call("No Exp obj"),
      "Not matching wrong type, default")

    verifyEq("2", 
       t.method("test").call(Exp("Woo", 3, Exp("Waa", 2))))

    verifyEq("Default",
       t.method("test").call(Exp("Woo", 2, Exp("Waa", 3))))

    verifyEq("3", 
       t.method("test").call([1, 2]))

    verifyEq("Default", 
       t.method("test").call([1, 1]))
  
    verifyEq("Default", 
       t.method("test").call([1, 2, 3]))
  }
  
  static const Str testPrg :=
     """
        using fantomPatternMatching

        class TestRunner
        {
  
          @DumpAstBefore
          @DumpAstAfter
          static Str test(Obj? o)
          {
            result := "Init"
            switch (o) {
              case Exp{child = Exp{age = 2}}: result = "2"
              case Exp{name = "Woo"; age = 3}: return "1"
              case [1, 2]: result = "3"
              default:
                return "Default"
            }
            
            return result
          }
  
          // @DumpAstBefore
          static Str expected(Obj? o)
          {
            result := "Init"
            switchObj := o
            hasMatched := false
            
            if (!hasMatched) {
              matchObj0 := switchObj as Exp
              if (matchObj0 != null) {
                 // case statement
                 hasMatched = true
                 result = "1"
              }
              if (!hasMatched) {
                return "Default"
              }
            }
  
            return result
  
          }
        }
        """
  
  
}

** Debug print AST before pattern expansion
facet class DumpAstBefore {}
** Debug print AST after pattern expansion
facet class DumpAstAfter {}

class Exp {
  Str name := "<empty>"
  Int age := 0
  Exp? child

  new makeDef(Str name, Int age, Exp? child := null)
  {
    this.name = name
    this.age = age
    this.child = child
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
