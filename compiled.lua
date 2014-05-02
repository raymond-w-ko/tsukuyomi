function tsukuyomi.core__SLASH__print(arg0)
    return print(arg0)
end
tsukuyomi.core__SLASH__print("first lisp code is now being executed!")
function tsukuyomi.core__SLASH__car(cell)
    return cell[1]
end
function tsukuyomi.core__SLASH__cdr(cell)
    return cell[2]
end
function tsukuyomi.core__SLASH__cadr(cell)
    local __Var6 = tsukuyomi.core__SLASH__cdr(cell)
    return tsukuyomi.core__SLASH__car(__Var6)
end
function tsukuyomi.core__SLASH__first(cell)
    return tsukuyomi.core__SLASH__car(cell)
end
function tsukuyomi.core__SLASH__ffirst(cell)
    local __Var7 = tsukuyomi.core__SLASH__first(cell)
    return tsukuyomi.core__SLASH__first(__Var7)
end
function tsukuyomi.core__SLASH__rest(cell)
    return tsukuyomi.core__SLASH__cdr(cell)
end
tsukuyomi.core__SLASH__list1 = tsukuyomi._consume_data(0)
local __Var0 = tsukuyomi.core__SLASH__car(tsukuyomi.core__SLASH__list1)
tsukuyomi.core__SLASH__print(__Var0)
local __Var1 = tsukuyomi.core__SLASH__cdr(tsukuyomi.core__SLASH__list1)
tsukuyomi.core__SLASH__print(__Var1)
local __Var2 = tsukuyomi.core__SLASH__cadr(tsukuyomi.core__SLASH__list1)
tsukuyomi.core__SLASH__print(__Var2)
local __Var3 = tsukuyomi.core__SLASH__first(tsukuyomi.core__SLASH__list1)
tsukuyomi.core__SLASH__print(__Var3)
local __Var4 = tsukuyomi.core__SLASH__rest(tsukuyomi.core__SLASH__list1)
tsukuyomi.core__SLASH__print(__Var4)
local __Var8 = tsukuyomi.core__SLASH__rest(tsukuyomi.core__SLASH__list1)
local __Var5 = tsukuyomi.core__SLASH__first(__Var8)
tsukuyomi.core__SLASH__print(__Var5)