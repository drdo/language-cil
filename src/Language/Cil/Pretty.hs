-- |
-- Pretty-printer for the abstract syntax.
-- Currenty uses ShowS, maybe should use some PP combinator library?
--

module Language.Cil.Pretty (
    Pretty (pr)
  ) where

import Language.Cil.Syntax

import Data.Bool.Extras (bool)
import Data.List (intersperse, intercalate)

{- Alternative to deriving Show

instance Show Assembly where
  show a = pr a ""
-}

class Pretty a where
  -- | Serializes a Cil data structure to a String.
  pr :: a -> ShowS

-- | Serializes a DottedName, escaping some weird names (such as \'add\' 
-- or '<Thunk>').
prName :: DottedName -> ShowS
prName "" = error "Language.Cil.Pretty.prName: Name cannot be empty"
prName n  = if n `elem` kw || '<' `elem` n
             then (escape n ++)
             else (n ++)
  where
    kw = ["add", "pop", "value"]
    escape s = intercalate "/" (map (\s -> "'" ++ s ++ "'") (filter (/=[]) (split '/' s)))

split :: Eq a => a -> [a] -> [[a]]
split x xs = f xs []
  where
    f []     zs = [zs]
    f (y:ys) zs = if x == y
                      then zs:f ys []
                      else f ys (zs++[y])

instance Pretty Assembly where
  pr (Assembly as n ts) =
      foldr (\a s -> pr a . s) id as
    . (".assembly " ++) . prName n . (" {}\n" ++)
    . foldr (\t s -> pr t . nl . s) id ts

instance Pretty AssemblyRef where
  pr (AssemblyRef n) = (".assembly extern " ++) . (n ++) . (" {}\n" ++)

instance Pretty TypeDef where
  pr (Class cas n et its ds) =
      (".class " ++)
    . prList cas . prName n
    . maybe id (\e -> sp . ("extends " ++) . pr e) et
    . bool (sp . ("implements " ++) . foldr (.) id (map pr its)) id (null its)
    . ("\n{\n" ++)
    . foldr (\d s -> pr d . s) id ds
    . ("}\n" ++)
  pr (GenericClass cas n ps ds) =
      (".class " ++) . prList cas . prName n
    . ("`" ++) . shows (length ps) . ("<" ++)
    . foldr (.) id (intersperse (", " ++) (map pr ps))
    . (">\n{\n" ++)
    . foldr (\d s -> pr d . s) id ds
    . ("}\n" ++)

instance Pretty GenParam where
  pr (GenParam n) = prName n

instance Pretty ClassAttr where
  pr CaPrivate       = ("private" ++)
  pr CaPublic        = ("public" ++)
  pr CaNestedPublic  = ("nested public" ++)
  pr CaNestedPrivate = ("nested private" ++)

instance Pretty ClassDecl where
  pr (FieldDef fd)  = pr fd
  pr (MethodDef md) = pr md
  pr (TypeDef td)   = pr td

instance Pretty TypeSpec where
  pr (TypeSpec nm) = prName nm

instance Pretty FieldDef where
  pr (Field fas t n) = 
      ident . (".field " ++)
    . prList fas
    . pr t . sp . prName n . nl

instance Pretty FieldAttr where
  pr (FaStatic)    = ("static" ++)
  pr (FaPublic)    = ("public" ++)
  pr (FaPrivate)   = ("private" ++)
  pr (FaAssembly)  = ("assembly" ++)

instance Pretty MethodDef where
  pr (Constructor mas t ps ms) =
      ident . (".method " ++)
    . prList mas . pr t . sp . (".ctor(" ++)
    . foldr (.) id (intersperse (", " ++) (map pr ps))
    . (") cil managed\n" ++)
    . ident . ("{\n" ++)
    . foldr (\m s -> pr m . s) id ms
    . ident . ("}\n" ++)
  pr (Method mas t n ps ms) =
      ident . (".method " ++)
    . prList mas
    . pr t . sp . prName n . ("(" ++)
    . foldr (.) id (intersperse (", " ++) (map pr ps))
    . (") cil managed\n" ++)
    . ident . ("{\n" ++)
    . foldr (\m s -> pr m . s) id ms
    . ident . ("}\n" ++)

instance Pretty MethAttr where
  pr (MaStatic)    = ("static" ++)
  pr (MaPublic)    = ("public" ++)
  pr (MaPrivate)   = ("private" ++)
  pr (MaAssembly)  = ("assembly" ++)
  pr (MaVirtual)   = ("virtual" ++)
  pr (MaHidebysig) = ("hidebysig" ++)

instance Pretty Parameter where
  pr (Param t n) = pr t . sp . prName n

instance Pretty MethodDecl where
  pr (Directive d) = pr d
  pr (Instr i)     = pr i
  pr (Comment s)   = ident . ident . ("// " ++) . (s ++) . nl

instance Pretty Instr where
  pr (OpCode oc)      = ident . ident . pr oc . nl
  pr (LabOpCode l oc) = ident . (l ++) . (":" ++) . nl
                               . ident . ident . pr oc . nl

instance Pretty Directive where
  pr (EntryPoint)    = ident . ident . (".entrypoint" ++) . nl
  pr (LocalsInit ls) =
    let bigident = ident . ident . ident . ident
    in
      ident . ident . (".locals init (" ++)
    . bool nl id (null ls)
    . foldr (.) id (intersperse (",\n" ++) (map (\l -> bigident . pr l) ls))
    . (")\n" ++)
  pr (MaxStack x)    = ident . ident . (".maxstack " ++) . shows x . nl

instance Pretty Local where
  pr (Local t n) = pr t . sp . prName n

instance Pretty OpCode where
  pr (Add)                 = ("add" ++)
  pr (And)                 = ("and" ++)
  pr (Beq l)               = ("beq " ++) . (l ++)
  pr (Bge l)               = ("bge " ++) . (l ++)
  pr (Bgt l)               = ("bgt " ++) . (l ++)
  pr (Ble l)               = ("ble " ++) . (l ++)
  pr (Blt l)               = ("blt " ++) . (l ++)
  pr (Box t)               = ("box " ++) . pr t
  pr (Br l)                = ("br " ++) . (l ++)
  pr (Brfalse l)           = ("brfalse " ++) . (l ++)
  pr (Brtrue l)            = ("brtrue " ++) . (l ++)
  pr (Call ccs t a c m ps) = ("call " ++) . prList ccs . pr t . sp
                               . prCall a c m ps
  pr (CallVirt t a c m ps) = ("callvirt instance " ++) . prsp t . sp
                               . prCall a c m ps
  pr (Ceq)                 = ("ceq" ++)
  pr (Cge)                 = ("cge" ++)
  pr (Cgt)                 = ("cgt" ++)
  pr (Cle)                 = ("cle" ++)
  pr (Clt)                 = ("clt" ++)
  pr (Dup)                 = ("dup" ++)
  pr (Isinst nm)           = ("isinst " ++) . prName nm
  pr (Ldarg x)             = ("ldarg " ++) . shows x
  pr (Ldarg_0)             = ("ldarg.0 " ++)
  pr (Ldarg_1)             = ("ldarg.1 " ++)
  pr (Ldarg_2)             = ("ldarg.2 " ++)
  pr (Ldarg_3)             = ("ldarg.3 " ++)
  pr (LdargN nm)           = ("ldarg " ++) . prName nm
  pr (Ldc_i4 x)            = ("ldc.i4 " ++) . shows x
  pr (Ldc_i4_0)            = ("ldc.i4.0 " ++) 
  pr (Ldc_i4_1)            = ("ldc.i4.1 " ++) 
  pr (Ldc_i4_2)            = ("ldc.i4.2 " ++) 
  pr (Ldc_i4_3)            = ("ldc.i4.3 " ++) 
  pr (Ldc_i4_4)            = ("ldc.i4.4 " ++) 
  pr (Ldc_i4_5)            = ("ldc.i4.5 " ++) 
  pr (Ldc_i4_6)            = ("ldc.i4.6 " ++) 
  pr (Ldc_i4_7)            = ("ldc.i4.7 " ++) 
  pr (Ldc_i4_8)            = ("ldc.i4.8 " ++) 
  pr (Ldc_i4_m1)           = ("ldc.i4.m1 " ++) 
  pr (Ldc_i4_s x)          = ("ldc.i4.s " ++)  . shows x
  pr (Ldfld t a c f)       = ("ldfld " ++) . pr t . sp . prFld a c f
  pr (Ldflda t a c f)      = ("ldflda " ++) . pr t . sp . prFld a c f
  pr (Ldind_ref)           = ("ldind.ref " ++)
  pr (Ldloc x)             = ("ldloc " ++) . shows x
  pr (Ldloc_0)             = ("ldloc.0 " ++)
  pr (Ldloc_1)             = ("ldloc.1 " ++)
  pr (Ldloc_2)             = ("ldloc.2 " ++)
  pr (Ldloc_3)             = ("ldloc.3 " ++)
  pr (LdlocN nm)           = ("ldloc " ++) . prName nm
  pr (Ldloca x)            = ("ldloca " ++) . shows x
  pr (LdlocaN nm)          = ("ldloca " ++) . prName nm
  pr (Ldsfld t a c f)      = ("ldsfld " ++) . pr t . sp . prFld a c f
  pr (Ldsflda t a c f)     = ("ldsflda " ++) . pr t . sp . prFld a c f
  pr (Ldstr s)             = ("ldstr " ++) . shows s
  pr (Mul)                 = ("mul" ++)
  pr (Neg)                 = ("neg" ++)
  pr (Newobj t a c ps)     = ("newobj instance " ++) . pr t . sp
                               . prNewobj a c ps
  pr (Nop)                 = ("nop" ++)
  pr (Pop)                 = ("pop" ++)
  pr (Rem)                 = ("rem" ++)
  pr (Ret)                 = ("ret" ++)
  pr (Stfld t a c f)       = ("stfld " ++) . pr t . sp . prFld a c f
  pr (Stind_ref)           = ("stind.ref " ++)
  pr (Stloc x)             = ("stloc " ++) . shows x
  pr (Stloc_0)             = ("stloc.0 " ++)
  pr (Stloc_1)             = ("stloc.1 " ++)
  pr (Stloc_2)             = ("stloc.2 " ++)
  pr (Stloc_3)             = ("stloc.3 " ++)
  pr (StlocN nm)           = ("stloc " ++) . prName nm
  pr (Stsfld t a c f)      = ("stsfld " ++) . pr t . sp . prFld a c f
  pr (Sub)                 = ("sub" ++)
  pr (Tail)                = ("tail." ++)
  pr (Tailcall opcode)     = ("tail. " ++) . pr opcode
  pr (Unbox t)             = ("unbox " ++) . pr t

instance Pretty CallConv where
  pr (CcInstance) = ("instance" ++)

prList :: (Pretty a) => [a] -> ShowS
prList = foldr (\x s -> pr x . sp . s) id

prFld :: DottedName -> DottedName -> DottedName -> ShowS
prFld a c f = 
    prAssembly a
  . (if c /= ""
     then prName c . ("::" ++)
     else id)
  . prName f

prNewobj :: DottedName -> DottedName -> [PrimitiveType] -> ShowS
prNewobj a c ps = 
    prAssembly a
  . (if c /= ""
     then prName c . ("::" ++)
     else id)
  . (".ctor(" ++)
  . foldr (.) id (intersperse (", " ++) (map pr ps))
  . (")" ++)

prCall :: DottedName -> DottedName -> DottedName -> [PrimitiveType] -> ShowS
prCall a c m ps = 
    prAssembly a
  . bool (prName c . ("::" ++)) id (c == "")
  . prName m
  . ("(" ++)
  . foldr (.) id (intersperse (", " ++) (map pr ps))
  . (")" ++)

prAssembly :: DottedName -> ShowS
prAssembly a = bool (("[" ++) . prName a . ("]" ++)) id (a == "")

instance Pretty PrimitiveType where
  pr Void                = ("void" ++) 
  pr Bool                = ("bool" ++)
  pr Char                = ("char" ++)
  pr Byte                = ("uint8" ++)
  pr Int32               = ("int32" ++)
  pr Int64               = ("int64" ++)
  pr String              = ("string" ++)
  pr Object              = ("object" ++)
  pr (ValueType a c)     = ("valuetype " ++) . prAssembly a . prName c
  pr (ReferenceType a c) = ("class " ++ ) . prAssembly a . prName c
  pr (GenericType x)     = ("!" ++) . shows x
  pr (ByRef pt)          = pr pt . ("&" ++)

-- Helper functions, to pretty print
prsp :: (Pretty a) => a -> ShowS
prsp x = let s = pr x ""
         in bool (pr x . sp) id (s == "")

ident = ("    " ++)
sp    = (" " ++)
nl    = ('\n' :)

