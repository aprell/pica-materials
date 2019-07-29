open IR
open Utils

type basic_block = Basic_block of name * source_info option

and source_info =
  { entry : name;
    exits : name list;
    stmts : stmt list;
    (* Line range *)
    source_loc : int * int; }

(* Constructor for basic blocks *)
let basic_block ?source_info name =
  Basic_block (name, source_info)

let add_line_numbers =
  List.map2 (Printf.sprintf "%3d %s")

let to_string (Basic_block (name, source_info)) : string =
  match source_info with
  | Some { stmts; source_loc = (a, b); _ } ->
    Printf.sprintf "[%s]\n%s"
      name
      (stmts
       |> List.map (string_of_stmt ~indent:4)
       |> add_line_numbers (a -- b)
       |> unlines)
  | None -> name

let gen_sym init =
  let count = ref init in
  fun ?(pref = "B") () ->
    let c = !count in
    incr count;
    pref ^ string_of_int c

let basic_blocks (code : stmt list) : basic_block list =
  let gen_sym = gen_sym 1 in
  List.fold_left (fun (label, start, line, blocks) stmt ->
      match stmt with
      | Jump target ->
        (* End current basic block *)
        let block = basic_block (gen_sym ()) ~source_info:
            { entry = label;
              exits = [target];
              stmts = sublist (start - 1) line code;
              source_loc = (start, line); }
        in
        (* Next line starts a new basic block *)
        ("fall-through", line + 1, line + 1, block :: blocks)
      | Cond (_, target) ->
        (* End current basic block *)
        let block = basic_block (gen_sym ()) ~source_info:
            { entry = label;
              exits = [target; "fall-through"];
              stmts = sublist (start - 1) line code;
              source_loc = (start, line); }
        in
        (* Next line starts a new basic block *)
        ("fall-through", line + 1, line + 1, block :: blocks)
      | Return _ ->
        (* End current basic block *)
        let block = basic_block (gen_sym ()) ~source_info:
            { entry = label;
              exits = ["exit"];
              stmts = sublist (start - 1) line code;
              source_loc = (start, line); }
        in
        (* Next line starts a new basic block *)
        ("fall-through", line + 1, line + 1, block :: blocks)
      | Label lab ->
        if start = line then
          (* Extend basic block *)
          (lab, start, line + 1, blocks)
        else
          (* End previous basic block *)
          let block = basic_block (gen_sym ()) ~source_info:
              { entry = label;
                exits = [lab];
                stmts = sublist (start - 1) (line - 1) code;
                source_loc = (start, line - 1); }
          in
          (* This line starts a new basic block *)
          (lab, line, line + 1, block :: blocks)
      | _ ->
        (* Extend basic block *)
        (label, start, line + 1, blocks)
    ) ("entry", 1, 1, []) code
  |> fun (_, _, _, blocks) -> List.rev blocks
