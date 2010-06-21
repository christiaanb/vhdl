-----------------------------------------------------------------------------
-- |
-- Module      :  Language.VHDL.AST
-- Copyright   :  (c) SAM Group, KTH/ICT/ECS 2007-2008
-- License     :  BSD-style (see the file LICENSE)
-- 
-- Maintainer  :  christiaan.baaij@gmail.com
-- Stability   :  experimental
-- Portability :  non-portable (Template Haskell)
--
-- A VHDL 93 subset AST (Abstract Syntax Tree), coded so that it can be easy 
-- to extend, please see doc/VHDL/vhdl93-syntax.html as reference 
-- in order to extend it (this AST is based on that grammar)
-----------------------------------------------------------------------------

-- This AST is aimed at code generation not parsing, and thus, 
-- it was simplified
-- The incompatibilities or simplifications from the standard
-- are properly commented

-- FIXME: shouldn't be records used instead of bare algebraic types?
-- FIXME: shouldn't the unused type redefinitions be removed?
-- FIXME: It would maybe be a good idea to create a sequence ADT which
--        guaranteed to hold at least one element (i.e. the grammar
--        has some cases such as "choices ::= choice | {choice}"
--        which are not well represented as "[Choice]", 
--        "Choices Choice  (Maybe [Choice])" is not easy to handle either
--        and thus, it was discarded.

module Language.VHDL.AST where

import Data.Char (toLower)
import Text.Regex.Posix

import Language.VHDL.Error


--------------------
-- VHDL identifiers
--------------------

-- VHDL identifier, use mkVHDLId to create it from a String, 
-- making sure a string is a proper VHDL identifier
data VHDLId = Basic String | Extended String
 deriving Eq

-- | Obtain the String of a VHDL identifier
fromVHDLId :: VHDLId -> String
fromVHDLId (Basic    str) = str
fromVHDLId (Extended str) = '\\' :  (escapeBackslashes str) ++ "\\"
 where escapeBackslashes [] = []
       escapeBackslashes (x : xs) 
        | x == '\\' = "\\\\" ++ escapeBackslashes xs
        | otherwise = x : escapeBackslashes xs
instance Show VHDLId where
 show  = show.fromVHDLId


-- | unsafely create a basic VHDLId (without cheking if the string is correct)
unsafeVHDLBasicId :: String -> VHDLId
unsafeVHDLBasicId str = Basic str


-- | unsafely create an exteded VHDLId (without cheking if the string is 
--   correct)
unsafeVHDLExtId :: String -> VHDLId
unsafeVHDLExtId str = Extended str


-- | Create a VHDL basic identifier from a String, previously checking if the  
--   String is correct
mkVHDLBasicId ::String -> EProne VHDLId
-- FIXME: we relax the fact that two consecutive underlines 
--        are not allowed
mkVHDLBasicId [] = throwError EmptyVHDLId
mkVHDLBasicId id
  | id =~ basiIdPat && (not $ elem lowId reservedWords) = return $ Basic id
  | otherwise = throwError $ IncVHDLBasId id
 where lowId = map toLower id
       basiIdPat = "^[A-Za-z](_?[A-Za-z0-9])*$"

-- | Create a VHDL extended identifier from a String, previously checking 
--   if the String is correct. The input string must not include the initial
--   and ending backslashes nad the intermediate backslashes shouldn't be escaped.
mkVHDLExtId :: String -> EProne VHDLId
mkVHDLExtId [] = throwError EmptyVHDLId
mkVHDLExtId id
 | id =~ extIdPat = return $ Extended id
 | otherwise = throwError $ IncVHDLExtId id
 where -- Regular expression pattern for extended identifiers.
       -- According to the VHDL93 standard, an extended identifier must:
       --  * Start and end with a backslash '\'
       --  * Its middle characters can be
       --    * two contiguous backslashes \\
       --    * an alphanumeric (A-Za-z0-9)
       --    * a Special Character 
       --    * an Other Special Character 
       --      (backslashes can only appear in pairs as indicated above)
       -- 
       -- However, backslashes will be handled when printing the identifier,
       -- (an initial and ending backslash are added and the intermediate backslashes
       --  are escaped)
       --
       -- Note that we cannot use specialChars and otherSpecialChars
       -- to build the pattern because of the double-backslash rule
       -- and also, the right bracket (according to the posix
       -- standard) needs to go in the first place of a bracket
       -- expression to lose its special meaning.  Furthermore,
       -- (according to the POSIX standard as well) we also need to put
       -- '-' in the last place of the bracket expression.
   extIdPat = 
     "^[]A-Za-z0-9 \"#&\\'()*+,./:;<=>_|!$%@?[^`{}~-]+$"


-- | Unsafely append a string to a VHDL identifier (i.e. without checking if
--  the resulting identifier is valid)
unsafeIdAppend :: VHDLId -> String -> VHDLId
unsafeIdAppend (Basic id)    suffix = Basic $ id ++ suffix
unsafeIdAppend (Extended id) suffix = Extended $ id ++ suffix

-- | special characters as defined in the VHDL93 standard
specialChars :: [Char]
specialChars = ['"' , '#' , '&' , '\'' , '(' , ')' , '*' , '+' , ',',
                '-' , '.' , '/' , ':'  , ';' , '<' , '=' , '>' , '_' , '|']

-- | other special characters as defined in the VHDL93 standard
otherSpecialChars :: [Char]
otherSpecialChars =['!' , '$' , '%' , '@' , '?' , '[' , '\\' , ']',
                    '^' , '`' , '{' , '}' , '~']

-- | Reserved identifiers
reservedWords :: [String]
reservedWords = ["abs", "access", "after", "alias", "all", "and",
 "architecture", "array", "assert", "attribute", "begin", "block",
 "body", "buffer", "bus", "case", "component", "configuration",
 "constant", "disconnect", "downto", "else", "elsif", "end", "entity",
 "exit", "file", "for", "function", "generate", "generic", "group",
 "guarded", "if", "impure", "in", "inertial", "inout", "is", "label",
 "library", "linkage", "literal", "loop", "map", "mod", "nand", "new",
 "next", "nor", "not", "null", "of", "on", "open", "or", "others",
 "out", "package", "port", "postponed", "procedure", "process", "pure",
 "range", "record", "register", "reject", "rem", "report", "return",
 "rol", "ror", "select", "severity", "shared", "signal", "sla", "sll",
 "sra", "srl", "subtype", "then", "to", "transport", "type",
 "unaffected", "units", "until", "use", "variable", "wait", "when",
 "while", "with", "xnor", "xor"]




   ---------
   -- AST --
   ---------


-- { } (0 or more) is expressed as [ ]
-- [ ] (optional) is expressed as Maybe


-- design_file
-- Having ContextClauses associated to library units is messy
-- instead we only allow ContextClause for the whole design file.
-- Furthermore we incorrectly (and deliberately) accept a file with 
-- no library units 
data DesignFile = DesignFile [ContextItem] [LibraryUnit]  
 deriving Show

-- context_item
-- We don't allow the "name1,name2,name3" syntax, only one name is allowed
--  at once
data ContextItem = Library VHDLId | Use SelectedName
 deriving Show

-- library_unit
-- We avoid adding the overhead of a PrimaryUnit and SecondaryUnit types
data LibraryUnit = LUEntity EntityDec      | 
                   LUArch ArchBody         | 
                   LUPackageDec PackageDec |
                   LUPackageBody PackageBody
 deriving Show

-- entity_declaration
-- No declarative nor statemet part is allowed 
-- Only interface signal declarations are allowed in the port clause
data EntityDec = EntityDec VHDLId [IfaceSigDec]
 deriving Show

-- | interface_signal_declaration
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
--  at once
-- The Mode is mandatory
-- Bus is not allowed 
-- Preasigned values are not allowed
-- Subtype indications are not allowed, just a typemark 
-- Constraints are not allowed: just add a new type with the constarint
--  in ForSyDe.vhd if it is required
data IfaceSigDec = IfaceSigDec VHDLId Mode TypeMark
 deriving Show

-- | type_mark
-- We don't distinguish between type names and subtype names
-- We dont' support selected names, only simple names because we won't need
-- name selection (i.e. Use clauses will make name selection unnecesary)
type TypeMark = SimpleName


-- | mode
-- INOUT | BUFFER | LINKAGE are not allowed
data Mode = In | Out
 deriving (Show, Eq)

-- | architecture_body 
-- [ ARCHITECTURE ] and [ architecture_simple_name ] are not allowed
data ArchBody = ArchBody VHDLId VHDLName [BlockDecItem] [ConcSm]
 deriving Show

-- | package_declaration
--  [ PACKAGE ] and [ package_simple_name ] are not allowed
data PackageDec = PackageDec VHDLId [PackageDecItem]
 deriving Show


-- | package_declarative_item
-- only type declarations, subtype declarations and subprogram specifications 
-- (working as subprogram_declaration) allowed
data PackageDecItem = PDITD TypeDec | PDISD SubtypeDec | PDISS SubProgSpec
 deriving Show

-- | package_body
--  [ PACKAGE ] and [ package_simple_name ] are not allowed
data PackageBody = PackageBody VHDLId [PackageBodyDecItem]
 deriving Show

-- | only subprogram_body is allowed
type PackageBodyDecItem = SubProgBody

-- | subtype-declaration
data SubtypeDec = SubtypeDec VHDLId SubtypeIn
 deriving Show

-- | subtype_indication
--   resolution functions are not permitted
data SubtypeIn = SubtypeIn TypeMark (Maybe SubtypeConstraint)
 deriving Show

-- | constraint
-- Only index constraints are allowed
type Constraint = IndexConstraint

data SubtypeConstraint = ConstraintIndex Constraint | ConstraintRange Range
 deriving Show

-- | range
--   the direction must always be \"to\"
data Range =  AttribRange AttribName | 
              SubTypeRange Expr Expr |
              ToRange Expr Expr      |
              DownRange Expr Expr 
 deriving Show

-- | index_constraint
data IndexConstraint = IndexConstraint [DiscreteRange]
 deriving Show

-- | discrete_range
--   only ranges are allowed
type DiscreteRange = Range

-- | type_declaration
-- only full_type_declarations are allowed
data TypeDec = TypeDec VHDLId TypeDef
 deriving Show

-- | type_declaration
-- only composite types and enumeration types (a specific scalar type)
data TypeDef = TDA ArrayTypeDef | TDR RecordTypeDef | TDE EnumTypeDef | TDI IntegerTypeDef
 deriving Show

-- | array_type_definition
--     unconstrained_array_definition
--     constrained_array_definition
-- A TypeMark is used instead of a subtype_indication. If subtyping is required,
-- declare a subtype explicitly.  
data ArrayTypeDef = UnconsArrayDef [TypeMark] TypeMark |
                    ConsArrayDef IndexConstraint TypeMark
 deriving Show

-- | record_type_definition
-- [ record_type_simple_name ] not allowed
data RecordTypeDef = RecordTypeDef [ElementDec]
 deriving Show

-- | element_declaration 
-- multi-identifier element declarations not allowed
-- element_subtype_definition is simplified to a type_mark
data ElementDec = ElementDec VHDLId TypeMark
 deriving Show

-- | enumeration_type_definition 
--   enumeration literals can only be identifiers
data EnumTypeDef = EnumTypeDef [VHDLId]
 deriving Show

data IntegerTypeDef = IntegerTypeDef DiscreteRange
 deriving Show

-- | name
-- operator_names are not allowed 
data VHDLName = NSimple SimpleName     | 
                NSelected SelectedName | 
                NIndexed IndexedName   |
                NSlice SliceName       |
                NAttribute AttribName 
 deriving Show

-- | simple_name
type SimpleName = VHDLId

-- | selected_name
data SelectedName = Prefix :.: Suffix
 deriving Show

infixl :.:

-- | indexed_name
-- note that according to the VHDL93 grammar the index list cannot be empty 
data IndexedName = IndexedName Prefix [Expr]
 deriving Show

-- | prefix
--  only names (no function calls)
type Prefix = VHDLName

-- | suffix
-- no character or operator symbols are accepted
data Suffix = SSimple SimpleName | All
 deriving Show


-- | slice_name
data SliceName = SliceName Prefix DiscreteRange
 deriving Show

-- | attribute_name
--   signatures are not allowed
data AttribName = AttribName Prefix VHDLName (Maybe Expr)
 deriving Show

-- | block_declarative_item
-- Only subprogram bodies and signal declarations are allowed
data BlockDecItem = BDISPB SubProgBody | BDISD SigDec
 deriving Show


-- | subprogram_body
-- No subprogram kind nor designator is allowed
data SubProgBody = SubProgBody SubProgSpec [SubProgDecItem] [SeqSm]
 deriving Show

-- | subprogram_declarative_item
--   only varaible declarations are allowed.
data SubProgDecItem = SPVD VarDec | SPCD ConstDec | SPSB SubProgBody
 deriving Show

-- | variable_declaration
--   identifier lists are not allowed
data VarDec = VarDec VHDLId SubtypeIn (Maybe Expr)
 deriving Show

data ConstDec = ConstDec VHDLId SubtypeIn (Maybe Expr)
 deriving Show

-- | subprogram_specification
-- Only Functions are allowed
-- [Pure | Impure] is not allowed
-- Only an identifier is valid as the designator
-- In the formal parameter list only variable declarations are accepted  
data SubProgSpec = Function VHDLId [IfaceVarDec] TypeMark 
 deriving Show

-- | interface_variable_declaration
-- [variable] is not allowed
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
-- Mode is not allowed
-- Resolution functions and constraints are not allowed, thus a TypeMark
--  is used instead of a subtype_indication. If subtyping is required,
--  declare a subtype explicitly.
data IfaceVarDec = IfaceVarDec VHDLId TypeMark
 deriving Show

-- | sequential_statement
-- Only If, case, return, for loops, assignment, @wait for@ procedure calls
-- allowed.
-- Only for loops are allowed (thus loop_statement doesn't exist) and cannot
-- be provided labels.
-- The target cannot be an aggregate.
-- General wait statements are not allowed, only @wait for@
-- It is incorrect to have an empty [CaseSmAlt]
data SeqSm = IfSm  Expr [SeqSm] [ElseIf] (Maybe Else) |
             CaseSm Expr [CaseSmAlt]                  |
             ReturnSm (Maybe Expr)                    |
             ForSM VHDLId DiscreteRange [SeqSm]       |
             VHDLName := Expr                         |
             WaitFor Expr                             |
             SigAssign  VHDLName Wform                |
             ProcCall VHDLName [AssocElem]
 deriving Show

-- | helper type, they doesn't exist in the origianl grammar
data ElseIf = ElseIf Expr [SeqSm]
 deriving Show

-- | helper type, it doesn't exist in the origianl grammar
data Else = Else [SeqSm]
 deriving Show

-- | case_statement_alternative
-- it is incorrect to have an empty [Choice]
data CaseSmAlt = CaseSmAlt [Choice] [SeqSm]
 deriving Show

-- | choice
-- although any expression is allowed the grammar specfically only allows 
-- simple_expressions (not covered in this AST) 
data Choice = ChoiceE Expr | Others
 deriving Show

-- | signal_declaration
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
--  at once
-- Resolution functions and constraints are not allowed, thus a TypeMark
--  is used instead of a subtype_indication
-- Signal kinds are not allowed
data SigDec = SigDec VHDLId TypeMark (Maybe Expr)
 deriving Show

-- | concurrent_statement
-- only block statements, component instantiations and signal assignments 
-- are allowed
data ConcSm = CSBSm BlockSm | 
              CSSASm  ConSigAssignSm | 
              CSISm CompInsSm  |
              CSPSm ProcSm |
              CSGSm GenerateSm
 deriving Show

-- | block_statement
-- Generics are not supported
-- The port_clause (with only signals) and port_map_aspect are mandatory
-- The ending [ block_label ] is not allowed
-- 
data BlockSm = BlockSm Label [IfaceSigDec] PMapAspect [BlockDecItem] [ConcSm]
 deriving Show

-- | port_map_aspect
newtype PMapAspect = PMapAspect [AssocElem]
 deriving Show

-- | label
type Label = VHDLId

-- | association_element
data AssocElem = Maybe (FormalPart) :=>: ActualPart
 deriving Show

-- | formal_part
-- We only accept a formal_designator (which is a name after all),
-- in the forme of simple name (no need for selected names)   
--  "function_name ( formal_designator )" and "type_mark ( formal_designator )"
--  are not allowed
type FormalPart = SimpleName

-- | actual_part
-- We only accept an actual_designator,
--  "function_name ( actual_designator )" and "type_mark ( actual_designator )"
--  are not allowed
type ActualPart = ActualDesig

-- | actual_designator
data ActualDesig = ADName VHDLName | ADExpr Expr | Open
 deriving Show

-- | concurrent_signal_assignment_statement
-- Only conditional_signal_assignment is allowed (without options)
-- The LHS (targets) are simply signal names, no aggregates
data ConSigAssignSm = VHDLName :<==: ConWforms
 deriving Show

-- | conditional_waveforms 
data ConWforms = ConWforms [WhenElse] Wform (Maybe When)  
 deriving Show

-- | Helper type, it doesn't exist in the VHDL grammar
data WhenElse = WhenElse Wform Expr
 deriving Show

-- | Helper type, it doesn't exist in the VHDL grammar
newtype When = When Expr
 deriving Show

-- | waveform
-- although it is possible to leave [Expr] empty, that's obviously not
-- valid VHDL waveform
data Wform = Wform [WformElem] | Unaffected
 deriving Show

-- | waveform_element
--   Null is not accepted
data WformElem = WformElem Expr (Maybe Expr)
 deriving Show

           
-- | component_instantiation_statement
-- No generics supported
-- The port map aspect is mandatory
data CompInsSm = CompInsSm Label InsUnit PMapAspect
 deriving Show

-- | process_statement
--   The label is mandatory
--   Only simple names are accepted in the sensitivity list
--   No declarative part is allowed
data ProcSm = ProcSm Label [SimpleName] [SeqSm]
 deriving Show

-- | instantiated_unit
-- Only Entities are allowed and their architecture cannot be specified
data InsUnit = IUEntity VHDLName
 deriving Show

data GenerateSm = GenerateSm Label GenSm [BlockDecItem] [ConcSm]
  deriving Show

data GenSm = ForGn VHDLId DiscreteRange |
             IfGn  Expr
  deriving Show

-----------------
-- Expression AST
-----------------

-- | expression, instead of creating an AST like the grammar 
-- (see commented section below) we made our own expressions which are 
-- easier to handle, but which don't don't show operand precedence
-- (that is a responsibility of the pretty printer)

data Expr = -- Logical operations
            And  Expr Expr    |
            Or   Expr Expr    |
            Xor  Expr Expr    |
            Nand Expr Expr    |
            Nor  Expr Expr    |
            Xnor Expr Expr    |
            -- Relational Operators
            Expr :=:  Expr    |
            Expr :/=: Expr    |
            Expr :<:  Expr    |
            Expr :<=: Expr    |
            Expr :>:  Expr    |
            Expr :>=: Expr    |
            -- Shift Operators
            Sll Expr Expr     |
            Srl Expr Expr     |
            Sla Expr Expr     |
            Sra Expr Expr     |
            Rol Expr Expr     |
            Ror Expr Expr     |
            -- Adding Operators
            Expr :+: Expr     |
            Expr :-: Expr     |
            Expr :&: Expr     |
            -- Sign Operators
            Neg Expr          |
            Pos Expr          |
            -- Multiplying Operators
            Expr :*: Expr     |
            Expr :/: Expr     |
            Mod  Expr Expr    |
            Rem  Expr Expr    |
            -- Miscellaneous Operators
            Expr :**: Expr    |
            Abs  Expr         |
            Not  Expr         |
            -- Primary expressions
            -- Only literals, names and function calls  are allowed
            PrimName VHDLName |
            PrimLit   Literal |
            PrimFCall FCall   |       
            -- Composite_types-related operators
            Aggregate [ElemAssoc]   -- (exp1,exp2,exp3, ...)
 deriving Show            

-- operand precedences, according to the VHDL LRM: 
--  "Where the language
--   allows a sequence of operators, operators with the same
--   precedence level are associated with their operands in textual
--   order, from left to right." In other words, they are all left associative
--
--   For example: a / b / c    = (a/b)/c
--                a and b or c  is illegal (mixing operators is not allowed
--                                          by the language and only
--                                          can avoid parenthesis in some 
--                                          cases)

infixl 2 `And`, `Or`, `Xor`, `Nand`, `Nor`, `Xnor`
infixl 3 :=:, :/=:, :<:, :<=:, :>:, :>=:
infixl 4 `Sll`, `Srl`, `Sla`, `Sra`, `Rol`, `Ror`
infixl 5 :+:, :-:, :&:
infix  6 `Neg`, `Pos`  
infixl 7 :*:, :/:, `Mod`, `Rem`
infixl 8 :**:, `Abs`,  `Not` 

-- | Logical Operators precedence
logicalPrec :: Int
logicalPrec = 2

-- | Relational Operators Precedence
relationalPrec :: Int
relationalPrec = 3

-- | Shift Operators Precedence
shiftPrec :: Int
shiftPrec = 4

-- | Plus Operators precedence
plusPrec :: Int
plusPrec = 5

-- | Sign Operators Precedence
signPrec :: Int
signPrec = 6

-- | Multplying Operators Precedecne
multPrec :: Int
multPrec = 7

-- | Miscellaneous Operators Precedence
miscPrec :: Int
miscPrec = 8




-- | element_association
--   only one choice is allowed
data ElemAssoc = ElemAssoc (Maybe Choice) Expr
 deriving Show

-- | literal
-- Literals are expressed as a string (remember we are generating
-- code, not parsing)
type Literal = String

-- | function_call
data FCall = FCall VHDLName [AssocElem]
 deriving Show
             
            
{-

Expression AST following the grammar (discarded)

-- again, even if it possible to leave the [Relation] lists empty
-- that wouldn't be valid VHDL code
-- regading  NandExpr and NorExpr, their Relation list should 
-- have a maximum size of two (i.e. NandExpr Expr (Maybe Expr))
data Expr = AndExpr  [Relation] | 
            OrExpr   [Relation] |
            XorExpr  [Relation] |
            NandExpr [Relation] |
            NorExpr  [Relation] |
            XnorExpr [Relation]
 deriving Show

-- relation            
data Relation = Relation ShiftExpr  (Maybe (RelOp,ShiftExpr))
 deriving Show

-- relational_operator
data RelOp = Eq | NEq | Less | LessEq | Gter | GterEq 
 deriving Show 

-- shift_expression
data ShiftExpr = ShiftExpr SimpleExpr (Maybe(ShiftOp,SimpleExpr)) 
 deriving Show

-- simple_expression
data SimpleExpr = SimpleExpr (Maybe Sign) Term [(AddOp,Term)]
 deriving Show

-- sign
data Sign = Pos | Neg
 deriving Show

-- shift_operator
data ShiftOp = Sll | Srl | Sla | Sra | Rol | Ror
 deriving Show 

-- adding_operator
data AddOp = Plus | Minus | Concat 
 deriving Show

-- term
data Term = Term Factor (Maybe (MultOp, Factor))
 deriving Show

-- multiplying_operator
data MultOp = Mult | Div | Mod | Rem
 deriving Show

-- factor
data Factor = Exp Primary (Maybe (Primary)) |
              Abs Primary                   |
              Not Primary
 deriving Show

-- primary
-- Only literals, names and function calls  are allowed
data Primary = PrimName  VHDLName    |
               PrimLit   Literal |
               PrimFCall FCall
 deriving Show

-- literal
-- Literals are expressed as a string (remember we are generating
-- code, not parsing)
type Literal = String

-- function_call
data FCall = FCall VHDLName [AssocElem]
 deriving Show
-}
