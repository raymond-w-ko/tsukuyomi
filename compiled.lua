tsukuyomi['core']['print'] = function (arg0)
    return print(arg0)
end
local __Var0 = tsukuyomi['core']['print']
__Var0("first lisp code is now being executed!")
tsukuyomi['core']['car'] = function (cell)
    return cell[1]
end
tsukuyomi['core']['cdr'] = function (cell)
    return cell[2]
end
tsukuyomi['core']['cadr'] = function (cell)
    local __Var7 = tsukuyomi['core']['car']
    local __Var21 = tsukuyomi['core']['cdr']
    local __Var22 = cell
    local __Var8 = __Var21(__Var22)
    return __Var7(__Var8)
end
tsukuyomi['core']['first'] = function (cell)
    local __Var9 = tsukuyomi['core']['car']
    local __Var10 = cell
    return __Var9(__Var10)
end
tsukuyomi['core']['ffirst'] = function (cell)
    local __Var11 = tsukuyomi['core']['first']
    local __Var23 = tsukuyomi['core']['first']
    local __Var24 = cell
    local __Var12 = __Var23(__Var24)
    return __Var11(__Var12)
end
tsukuyomi['core']['rest'] = function (cell)
    local __Var13 = tsukuyomi['core']['cdr']
    local __Var14 = cell
    return __Var13(__Var14)
end
tsukuyomi['core']['list1'] = tsukuyomi._consume_data(0)
local __Var1 = tsukuyomi['core']['print']
local __Var15 = tsukuyomi['core']['car']
local __Var16 = tsukuyomi['core']['list1']
local __Var2 = __Var15(__Var16)
__Var1(__Var2)
local __Var3 = tsukuyomi['core']['print']
local __Var17 = tsukuyomi['core']['cdr']
local __Var18 = tsukuyomi['core']['list1']
local __Var4 = __Var17(__Var18)
__Var3(__Var4)
local __Var5 = tsukuyomi['core']['print']
local __Var19 = tsukuyomi['core']['cadr']
local __Var20 = tsukuyomi['core']['list1']
local __Var6 = __Var19(__Var20)
__Var5(__Var6)