; extends

; C++ named cast operators (static_cast<T>(x), etc.) parse grammatically like
; a template function call, so the base query captures them as @function.call
; instead of a keyword. Override by literal identifier text, with higher
; priority so this wins over that generic capture.
((identifier) @keyword
  (#any-of? @keyword "static_cast" "reinterpret_cast" "const_cast" "dynamic_cast")
  (#set! priority 110))
