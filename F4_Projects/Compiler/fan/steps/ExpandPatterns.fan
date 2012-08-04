
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
    if ( !def.isSynthetic ) {
      dump("enterMethodDef")
      def.dump
    }
  }

  override Void exitMethodDef(MethodDef def)
  {
    super.exitMethodDef(def)

    // TODO: Debug code, to be removed
    if ( !def.isSynthetic ) {
      dump("exitMethodDef")
      def.dump
    }
  }
  
  
  override Stmt[]? visitStmt(Stmt stmt)
  {
    dump(stmt)

    if (stmt.id != StmtId.switchStmt) return null
    
    swch := (SwitchStmt) stmt
    
    doMatch := swch.cases.any { it.cases.any { isItBlockCtor(it) } }
    
    if (doMatch) {
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
  private MethodVar? hasMatched
  private MethodVar? switchObjVar
  
  private ExpandPatterns step
  private SwitchStmt? swch
  
  private Int objVarNr := 0
  
  new make(SwitchStmt swch, ExpandPatterns step)
  {
    this.step = step
    this.swch = swch
  }
  
  Void dump( Obj? s ) {
    step.log.debug("SwitchSubs: " + s)
  }

  Stmt[] run()
  {
    // Set up hasMatched variable
    // TODO: fix name to enable nested switches. Or is that nessesary?
    hasMatchedStmt := LocalDefStmt(swch.loc, step.ns.boolType, "hasMatched\$")
    
    hasMatchedStmt.var = step.curMethod.addLocalVarForDef(hasMatchedStmt, step.curMethod.code) // TODO: Smaller scope?
    hasMatched = hasMatchedStmt.var
    
    hasMatchedStmt.init = BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, hasMatched),
      LiteralExpr.makeFalse(swch.loc, step.ns))

    // Set up matchObj variable
    // TODO: fix name to enable nested switches.
    switchObjStmt := LocalDefStmt(swch.loc, swch.condition.ctype, "switchObj\$")
    
    switchObjStmt.var = step.curMethod.addLocalVarForDef(switchObjStmt, step.curMethod.code) // TODO: Smaller scope?
    switchObjVar = switchObjStmt.var
    
    switchObjStmt.init = BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, switchObjVar), swch.condition)
    
    // Generate the acctual match logic
    matchCode := handleCases(swch.cases.ro)
    
//    dump( "AST old start" )
//    swch.dump
//    dump( "AST old end" )
    
    result := Stmt[hasMatchedStmt, switchObjStmt].addAll(matchCode)

//    dump( "AST old start" )
//    result.each { it.dump }
//    dump( "AST old end" )

    return result
  }

  **
  ** Recurses over all cases in a switch
  ** 
  private Stmt[] handleCases(Case[] cases)
  {
    // Emit hasMatched test
    hasMatchedTest := IfStmt(swch.loc,
            UnaryExpr(swch.loc, // TODO: Set better location
                ExprId.boolNot, 
                Token.bang,
                LocalVarExpr(swch.loc, hasMatched)), 
                Block(swch.loc)
              )

    // Base case: If all cases have been handled emit the default block and return
    if (cases.isEmpty) {
      if (swch.defaultBlock != null) {
        // If there is def block, test for has matched and emit def block
        hasMatchedTest.trueBlock = swch.defaultBlock
        return [hasMatchedTest]
      } else {
        // If no def block just return
        return [,]
      }
    }
    
    cse := cases.first
    testExpr := cse.cases.first // TODO: Handle multiple tests for one case

    // Set a more precise loc
    hasMatchedTest.trueBlock.loc = testExpr.loc 

    // Make test for pattern in this case
    hasMatchedTest.trueBlock.addAll(makePatternTest(testExpr, cse))
    
    // Handle next case
    hasMatchedTest.trueBlock.addAll(handleCases(cases[1..-1].ro))
    
    return [hasMatchedTest]
  }
  
  private Stmt[] makePatternTest(Expr testExpr, Case cse)
  {
    result := Stmt[,]

    // Emit test for ctor pattern
    if (ExpandPatterns.isItBlockCtor(testExpr)) {
      result.addAll(makeCtorTest(testExpr, cse, LocalVarExpr(swch.loc, switchObjVar)))
    }
    // TODO: Emit test for other kinds of patterns

    return result
  }

  **
  ** Emit if statement for object creation pattern
  ** 
  private Stmt[] makeCtorTest(CallExpr ctorCall, Case cse, Expr matchObjExpr)
  {
    // Create match object
    matchObjDef := LocalDefStmt(cse.loc, ctorCall.ctype, "matchObj\$" + objVarNr++)
    MethodVar matchObjVar := step.curMethod.addLocalVarForDef(matchObjDef, step.curMethod.code)
    
    matchObjDef.init = BinaryExpr.makeAssign(
      LocalVarExpr(swch.loc, matchObjVar),
      TypeCheckExpr(swch.loc, ExprId.asExpr, matchObjExpr, ctorCall.ctype))
    
    // Emit test if match obj is right type for this clause
    typeTest := IfStmt(ctorCall.loc,
      UnaryExpr(
        ctorCall.loc,
        ExprId.cmpNotNull,
        Token.notEq,
        LocalVarExpr(ctorCall.loc, matchObjVar)),
      Block(ctorCall.loc))
    
    // Get the member assignment expressions from the it block closure.
    membs := ((((ctorCall.args.first as ClosureExpr).call.code.stmts.first as ExprStmt)
                      .expr as CallExpr).method as MethodDef).code.stmts[0..-2]
    
    dummyInspect(membs) // TODO: Remove
 
    // Check all fields in the ctor clause
    typeTest.trueBlock.addAll(makeMembTest(cse, membs))
    
    return [matchObjDef, typeTest]
  }
  
  static Obj? dummyInspect( Obj? o ) {
    return o
  }

  private Stmt[] makeMembTest(Case cse, Stmt[] membs)
  {
    if (membs.isEmpty) {
      return cse.block.stmts
    }
    
    return makeMembTest(cse, membs[1..-1])
    
        // Emit test if match obj is right type for this clause
//    typeTest := IfStmt(ctorCall.loc,
//      UnaryExpr(
//        ctorCall.loc,
//        ExprId.cmpNotNull,
//        Token.notEq,
//        LocalVarExpr(ctorCall.loc, matchObjVar)),
//      Block(ctorCall.loc))

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
















