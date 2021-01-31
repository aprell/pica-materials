open Three_address_code__IR
open Basic_block

module Set = Set.Make (struct
  type t = Basic_block.t ref * stmt ref ref
  let compare = Stdlib.compare
end)

(* Variables that are used as basic block parameters may introduce SSA names
 * for which no definitions exist. *)

type t = {
  def : Set.elt option;
  uses : Set.t;
}

let def_use_chains = Hashtbl.create 10

let get_def var =
  match Hashtbl.find_opt def_use_chains var with
  | Some { def; _ } -> def
  | None -> None

let get_uses var =
  match Hashtbl.find_opt def_use_chains var with
  | Some { uses; _ } -> uses
  | None -> Set.empty

let remove_use use var =
  match Hashtbl.find_opt def_use_chains var with
  | Some ({ uses; _ } as def_use_chain) ->
    assert (uses <> Set.empty);
    Hashtbl.replace def_use_chains var
      { def_use_chain with uses = Set.remove use uses }
  | None -> ()

let remove_uses var =
  match Hashtbl.find_opt def_use_chains var with
  | Some def_use_chain ->
    Hashtbl.replace def_use_chains var
      { def_use_chain with uses = Set.empty }
  | None -> ()

let remove_def var =
  match Hashtbl.find_opt def_use_chains var with
  | Some { def = Some ((_, stmt) as def); _ } -> (
      match !(!stmt) with
      | Move (_, e) ->
        List.iter (remove_use def) (all_variables_expr e)
      | Load (_, Deref y) ->
        remove_use def y
      | Label (_, Some xs)
      | Phi (_, xs) ->
        List.iter (remove_use def) xs
      | _ -> assert false
    );
    Hashtbl.remove def_use_chains var
  | Some { def = None; _ } ->
    Hashtbl.remove def_use_chains var
  | None -> ()

let add_def block stmt var =
  match Hashtbl.find_opt def_use_chains var with
  | Some ({ def; _ } as def_use_chain) ->
    assert (Option.is_none def);
    Hashtbl.replace def_use_chains var
      { def_use_chain with def = Some (ref block, ref stmt) }
  | None ->
    Hashtbl.add def_use_chains var
      { def = Some (ref block, ref stmt); uses = Set.empty; }

let add_use block stmt var =
  match Hashtbl.find_opt def_use_chains var with
  | Some ({ uses; _ } as def_use_chain) ->
    Hashtbl.replace def_use_chains var
      { def_use_chain with uses = Set.add (ref block, ref stmt) uses }
  | None ->
    Hashtbl.add def_use_chains var
      { def = None; uses = Set.singleton (ref block, ref stmt); }

let build block =
  let visit stmt =
    match !stmt with
    | Move (x, e) ->
      add_def block stmt x;
      List.iter (add_use block stmt) (all_variables_expr e)
    | Load (x, Deref y) ->
      add_def block stmt x;
      add_use block stmt y
    | Store (Deref x, e) ->
      add_use block stmt x;
      List.iter (add_use block stmt) (all_variables_expr e)
    | Label (_, Some xs) ->
      List.iter (add_def block stmt) xs
    | Cond (e, _, _) ->
      List.iter (add_use block stmt) (all_variables_expr e)
    | Receive x ->
      add_def block stmt x
    | Return (Some e) ->
      List.iter (add_use block stmt) (all_variables_expr e)
    | Return None -> ()
    | Phi (x, xs) ->
      add_def block stmt x;
      List.iter (add_use block stmt) xs
    | _ -> ()
  in
  List.iter visit block.stmts

let iter f =
  Hashtbl.iter (fun var { def; uses; } ->
      f var def uses
    ) def_use_chains

let clear () =
  Hashtbl.reset def_use_chains
