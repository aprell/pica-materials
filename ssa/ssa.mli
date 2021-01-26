open Control_flow

val parameterize_labels : Cfg.t -> unit

val rename_variables : Cfg.t -> unit

val insert_phi_functions : Cfg.t -> unit

val minimize_phi_functions : Cfg.t -> unit

val convert_to_ssa : Cfg.t -> unit

module Graph : sig
  type t
  val create : unit -> t
  val output_dot : ?filename:string -> t -> unit
end
