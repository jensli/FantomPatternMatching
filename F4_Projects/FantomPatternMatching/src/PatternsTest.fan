using compiler_new

class PatternsTest : Test
{
  Pod pod
  
  static const Unsafe nr
  
  static {
    nr = Unsafe([0])
  }
  
  new make() {
    echo( "MAKE" )
    pod = compile(testPrg)
  }
  
  
  Pod compile(Str src)
  {
    input := CompilerInput {
        podName     = "patternTestPod"
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
    echo("testSimple")
    t := pod.type("TestClass").make
    
    verifyEq("1", t->test(Exp("Woo", 3)), "Matching")
     
    verifyEq("def", t->test("No Exp obj"), "Not matching wrong type, default")

    verifyEq("2", t->test(Exp("Woo", 3, Exp("Waa", 2))))

    verifyEq("def", t->test(Exp("Woo", 2, Exp("Waa", 3))))

    verifyEq("3", t->test([1, 2]))

    verifyEq("def", t->test([1, 1]))
  
    verifyEq("def", t->test([1, 2, 3]))
  }
  
  // TODO: Who doesn't this work?!
  Void HIDE_testList()
  {
    echo("testList")
    t := pod.type("TestClass").make
    
    verifyEq("1", t->testList([1, 2]))
  }

  static const Str testPrg :=
     """
        using fantomPatternMatching

  
        class TestClass
        {
          @DumpAstBefore
          @DumpAstAfter
          Str test(Obj? o)
          {
            result := "Init"
            switch (o) {
              case Exp{child = Exp{age = 2}}: return "2"
              case Exp{name = "Woo"; age = 3}: result = "1"
              case [1, 2]: return "3"
              default:
                return "def"
            }
            
            return result
          }

  
          Str testNormalSwich(Obj? o)
          {
            switch (o) {
              case 1: return "1"
              case 2: return "2"
              default:
                return "def"
            }
          }

          @DumpAstAfter
          Str testReturn(Obj? o)
          {
            switch (o) {
              case [1]: return "1"
              case [2]: return "2"
              default:
                return "def"
            }
          }
          
          @DumpAstBefore
          @DumpAstAfter
          Str testList(Obj? o)
          {
            switch (o) {
              case [1, 2]: return "1"
              case [,]: return "empty"
              default: return "def"
            }
  
            return "nomatch"
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
                return "default"
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
