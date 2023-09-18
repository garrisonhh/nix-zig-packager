{ lib, input }:
let
  inherit (lib) strings;
  inherit (builtins) head tail elemAt length substring stringLength foldl'
    match listToAttrs;

  # parser state
  success = data: text:{
    success = true;
    inherit data text;
  };

  failure = msg: text: {
    success = false;
    inherit msg text;
  };

  # parser combinators =========================================================

  # match an exact string
  exact = token: text: (
    if strings.hasPrefix token text then
      success token (substring (stringLength token) (stringLength text) text)
    else
      failure "expected `${token}`" text
  );

  wrapRegex = regex: msg: text: (
    let matches = match regex text;
    in
    if matches != null then
      let token = elemAt matches 0;
      in
      success token (substring (stringLength token) (stringLength text) text)
    else
      failure msg text
  );

  # match two parsers in order
  each = lhs: rhs: text: (
    let lhsRes = lhs text;
    in
    if lhsRes.success then
      let rhsRes = rhs lhsRes.text;
      in
      if rhsRes.success then
        success [lhsRes.data rhsRes.data] rhsRes.text
      else
        rhsRes
    else
      lhsRes
  );

  # match one of two parsers
  either = lhs: rhs: text: (
    let lhsRes = lhs text;
    in
    if lhsRes.success then
      lhsRes
    else
      let rhsRes = rhs text;
      in
      if rhsRes.success then
        rhsRes
      else
        failure "${lhsRes.msg}\n${rhsRes.msg}" text
  );

  # if parser succeeds, map some function to the data
  map = f: parser: text: (
    let res = parser text;
    in
    if res.success then
      success (f res.data) res.text
    else
      res
  );

  # match on a parser and then retrieve an element
  extractElemAt = index: parser: text: (
    map (x: elemAt x index) parser text
  );

  left = lhs: rhs: extractElemAt 0 (each lhs rhs);

  right = lhs: rhs: text: (
    let res = (each lhs rhs) text;
    in
    if res.success then
      success (elemAt res.data 1) res.text
    else
      res
  );

  # match 0 or more of parser
  zeroOrMore = parser: (
    let aux = xs: text:
      let res = parser text;
      in
      if res.success then
        aux (xs ++ [res.data]) res.text
      else
        success xs res.text;
    in
    aux []
  );

  # match 1 or more of parser
  oneOrMore = parser: (
    map
      (data: [(elemAt 0 data)] ++ (elemAt 1 data))
      (each parser (zeroOrMore parser))
  );

  # optionally match parser
  optional = parser: text: (
    let res = parser text;
    in
    if res.success then
      res
    else
      success null res.text
  );

  # match a list of parsers in order
  series = parsers: (
    let aux = parsers: data: text:
      if (length parsers) == 0 then
        success data text
      else
        let res = (head parsers) text;
        in
        if res.success then
          aux (tail parsers) (data ++ [res.data]) res.text
        else
          res;
    in
    aux parsers []
  );

  # match any of a list of parsers
  choice = parsers:
    foldl' either (head parsers) (tail parsers);

  # zon parser =================================================================

  spaces = wrapRegex
    "([[:space:]]*).*"
    null;

  string =
    extractElemAt 1 (series [
      (exact "\"")
      (wrapRegex "([^\"]*).*" "expected string")
      (exact "\"")
    ]);

  escaped_ident = right (exact ".@") string;

  unescaped_ident =
    right
      (exact ".")
      (wrapRegex
        "([-_a-zA-Z0-9]+).*"
        "expected identifier");

  ident = either unescaped_ident escaped_ident;

  maybe_comma = (optional (series [(exact ",") spaces]));

  value =
    choice [
      (left string spaces)
      kv_map
    ];

  kv_pair =
    map
      (pair: {
        name = elemAt pair 0;
        value = elemAt pair 1;
      })
      (each
        (left ident (series [spaces (exact "=") spaces]))
        (left value (each spaces maybe_comma)));

  kv_map =
    map
      listToAttrs
      (extractElemAt 2 (series [
        (exact ".{")
        spaces
        (zeroOrMore kv_pair)
        (exact "}")
        spaces
      ]));

  parse = kv_map;
in
let res = parse input;
in
if res.success then
  res.data
else {
  error = res.msg;
}