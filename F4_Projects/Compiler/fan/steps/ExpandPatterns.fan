
class ExpandPatterns : CompilerStep
{
  new make(Compiler compiler)
    : super(compiler)
  {
  }
  
  override Void run()
  {
    log.debug("ExpandPatterns")

    walk(compiler, VisitDepth.stmt)
  }
  
  Void dump( Obj? s ) {
    log.debug("ExpandPatterns.visitStmt: " + s)
  }
  
  override Void enterMethodDef(MethodDef def)
  {
    super.enterMethodDef(def)
    
    // TODO: Debug code, to be removed
    if (def.facets != null && def.facets.any {it.type.name == "DumpAstBefore"})
    {
      dump("enterMethodDef ------------------")
      def.dump
    }
  }

  override Void exitMethodDef(MethodDef def)
  {
    super.exitMethodDef(def)

    // TODO: Debug code, to be removed
    if (def.facets != null && def.facets.any {it.type.name == "DumpAstAfter"})
    {
      dump("exitMethodDef -------------------")
      def.dump
    }
  }
  
  
  override Stmt[]? visitStmt(Stmt stmt)
  {
    if (stmt.id != StmtId.switchStmt) return null
    
    swch := (SwitchStmt) stmt
    
    if (swch.cases.any { it.cases.any { isItBlockCtor(it) } }) {
      dump("Match switch found")
      return SwitchSubs(swch, this).run
    } else {
      return null
    }
  }
  
  static Bool isItBlockCtor(Expr expr)
  {
    if (expr.id != ExprId.call) return false
    call := expr as CallExpr
    return call.method.isItBlockCtor
  }

}

internal class SwitchSubs
{
  // Variable that is set when a pattern has matched, and checked before trying the next
  // pattern
  private MethodVar? hasMatchedVar
  
  // Holds the value of evaluating the expression that is switched on
  private MethodVar? switchObjVar
  
  // The running compiler step
  private ExpandPatterns step

  // The original swich statment
  private SwitchStmt? swch
  
  // An ID nr for sub patterns variable names
  private Int objVarNr := 0
  
  new make(SwitchStmt swch, ExpandPatterns step)
  {
    this.step = step
    this.swch = swch
  }
  
  private Int nextId() {
    return objVarNr++
  }
  
  
  Void dump( Obj? s ) {
    step.log.debug("SwitchSubs: " + s)
  }

  Stmt[] run()
  {
    // Set up hasMatched variable
    // TODO: Remove temp name
    hasMatchedVar = step.curMethod.addLocalVar(step.ns.boolType, "hasMatched", step.curMethod.code)
    hasMatchedStmt := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, hasMatchedVar),
      LiteralExpr.makeFalse(swch.loc, step.ns)).toStmt
    
    // Set up matchObj variable
    // TODO: Remove temp name
    switchObjVar = step.curMethod.addLocalVar(
      swch.condition.ctype, "switchObj", step.curMethod.code)
    switchObjStmt := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, switchObjVar), swch.condition).toStmt
    
    // Generate the acctual match logic
    matchCode := handleCases(swch.cases.ro)
    
    return Stmt[hasMatchedStmt, switchObjStmt].addAll(matchCode)
  }

  **
  ** Recurses over all cases in a switch, returning test statments for each case. 
  ** 
  **  
  private Stmt[] handleCases(Case[] cases)
  {
    // Create hasMatched test
    hasMatchedTest := IfStmt(swch.loc,
            UnaryExpr(swch.loc, // TODO: Set better location
                ExprId.boolNot, 
                Token.bang,
                LocalVarExpr(swch.loc, hasMatchedVar)), 
                Block(swch.loc)
              )

    // Base case: If all cases have been handled emit the default block and return
    if (cases.isEmpty) {
      if (swch.defaultBlock != null) {
        // If there is def block, test for has matched and emit def block
        hasMatchedTest.trueBlock = swch.defaultBlock
        return [hasMatchedTest]
      } else {
        return [,] // If no def block just return
      }
    }
    
    cse := cases.first
    testExpr := cse.cases.first // TODO: Handle multiple cases for one branch

    hasMatchedTest.trueBlock.loc = testExpr.loc // Set a more precise loc 
    
//    // Make test for pattern in this case

    // Make test for pattern in this case
    tests := makePatternTest(testExpr, LocalVarExpr(swch.loc, switchObjVar), cse)
    
    // Add the branch code, and the hasMatch = true statement, if this isnt a return
    if (!cse.block.isExit)
    {
      tests.last.extSpot.add(
        ExprStmt(
          BinaryExpr.makeAssign(
              LocalVarExpr(swch.loc, hasMatchedVar),
              LiteralExpr.makeTrue(swch.loc, step.ns))))
    }

    // Add the branch code after the last test, when its known that there is a match 
    tests.last.extSpot.addAll(cse.block.stmts)

    // Put each test in the previous ones extSpot
    tests.each |testStmt, i| {
      if (i == 0) return
      tests[i-1].extSpot.addAll(testStmt.testStmts)
    }
    
    // Add all the tests in the has matched test 
    hasMatchedTest.trueBlock.addAll(tests[0].testStmts)

    restTestCode := handleCases(cases[1..-1])
    
    // Handle next case
    hasMatchedTest.trueBlock.addAll(restTestCode)
    
    return [hasMatchedTest]
  }
  
  
  **
  ** Checks the kind of pattern and calls the corresponding method. Called recursivly
  ** for sub patterns. Returns test statement.
  **
  ** testExpr: Expression describing the pattern
  ** matchObjExpr: Value to match against. Can only be used in one place, should be bould
  **    to var if used more times.
  ** cse: The current case branch
  **  
  private MatchTest[] makePatternTest(Expr testExpr, Expr matchObjExpr, Case cse)
  {
    result := MatchTest[,]
    
    // Emit test for ctor pattern
    if (ExpandPatterns.isItBlockCtor(testExpr))
    {
      return makeCtorTest(testExpr, matchObjExpr, cse)
    }
    else
    {
      return makeSimpleTest(testExpr, matchObjExpr, cse)
    }
    
    // TODO: Emit test for other kinds of patterns
    
    throw CompilerErr("Unknown pattern", cse.loc)
  }
  
  private MatchTest[] makeSimpleTest(Expr testExpr, Expr matchObjExpr, Case cse)
  {
    testStmt := IfStmt(
      testExpr.loc,  
      ShortcutExpr(matchObjExpr, Token.eq, testExpr) {
          method = step.ns.objType.method(ShortcutOp.eq.methodName)
//          method = testExpr.ctype.operators.find(ShortcutOp.eq.methodName).first
          name = method.name
        },
        Block(testExpr.loc))

    return [MatchTest([testStmt], testStmt.trueBlock.stmts)]
  }

  **
  ** Returns test statements for object creation pattern
  ** 
  private MatchTest[] makeCtorTest(CallExpr ctorCall, Expr matchObjExpr, Case cse)
  {
    // Create match object
    matchObjVar := step.curMethod.addLocalVar(ctorCall.ctype, null, step.curMethod.code)
    matchObjDef := BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, matchObjVar),
      TypeCheckExpr(swch.loc, ExprId.asExpr, matchObjExpr, ctorCall.ctype)).toStmt
    
    // Emit test if match obj is right type for this clause
    typeTest := IfStmt(ctorCall.loc,  
      UnaryExpr(
        ctorCall.loc,
        ExprId.cmpNotNull,
        Token.notEq,
        LocalVarExpr(ctorCall.loc, matchObjVar)),
      Block(ctorCall.loc))
    
    // Get the member assignment expressions from the it block closure,
    // removing the return statment at the end.
    membs := ((((ctorCall.args.first as ClosureExpr).call.code.stmts.first as ExprStmt)
              .expr as CallExpr).method as MethodDef).code.stmts[0..-2]
    
    // Check all fields in the ctor clause
    tests := membs.map(|Stmt stmt -> MatchTest[]|
      {
        assignExpr := (stmt as ExprStmt).expr as BinaryExpr
        if (assignExpr == null || assignExpr.id != ExprId.assign)
          throw CompilerErr("Only assignment exprs in patterns", stmt.loc)
        
        fieldExpr := assignExpr.lhs as FieldExpr
        
        // Recursive call for sub pattern
        return makePatternTest(
          assignExpr.rhs,
          FieldExpr(fieldExpr.loc, LocalVarExpr(fieldExpr.loc, matchObjVar), fieldExpr.field),
          cse)
      }).flatten

    return [MatchTest([matchObjDef, typeTest], typeTest.trueBlock.stmts)].addAll(tests)
  }
  
  static Obj? dummyInspect( Obj? o ) {
    return o
  }


}


class MatchTest {
  Stmt[] testStmts
  Stmt[] extSpot
  
  new make(Stmt[] test, Stmt[] extSpot) {
    this.testStmts = test
    this.extSpot = extSpot
  }
}



abstract class MatchSpec {
}

class ObjSpec : MatchSpec
{
  Type type
  MatchSpec[] members

  new make(|This -> Void| f) {
    f(this)
  }
}

class EqualsSpec : MatchSpec {
  Obj? obj
}
















