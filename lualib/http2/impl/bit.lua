local _M = { _VERSION = "0.1" }

function _M.band(a, b) return a & b end;
function _M.bor(a, b) return a | b end;
function _M.bxor(a, b) return a ~ b end;
function _M.bnot(a) return ~a end;
function _M.lshift(a, b) return a << b end;
function _M.rshift(a, b) return a >> b end;

return _M
