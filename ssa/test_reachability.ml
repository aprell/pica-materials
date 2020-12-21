open Control_flow
open Graphs
open Ssa

let print_basic_blocks graph =
  Cfg.basic_blocks graph
  |> List.map Basic_block.to_string
  |> List.filter (fun name -> name <> "Entry" && name <> "Exit")
  |> String.concat "\n"
  |> print_endline

let () =
  let graph =
    graph_of_input
      (match Sys.argv with
       | [| _; filename |] -> filename
       | _ -> "examples/pow.hir")
  in
  convert_to_ssa graph;
(*   Ssa__Optim.optimize (); *)
  print_basic_blocks graph;
  let worklist = Reachability.init graph in
  print_newline ();
  Reachability.print ();
  print_newline ();
  Reachability.iterate worklist;
  print_newline ();
  Reachability.print ()
