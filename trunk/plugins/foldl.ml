#load "q_MLast.cmo";;

open Pa_gt.Plugin
open List
open Printf

let _ =
  register "foldl" 
    (fun loc d -> 
       let module H = Helper (struct let loc = loc end) in       
       H.(
        let gen   = name_generator (d.name::d.type_args) in
	let syn   = gen#generate "syn" in
        {
          inh_t       = T.var syn; 
          syn_t       = T.var syn;
          proper_args = flatten (map (fun a -> [a; syn]) d.type_args); 
          arg_img     = (fun _ -> T.var syn)
        }, 
        object
	  inherit generator
	  method constr env constr =
	    fold_left 
              (fun inh (arg, typ) ->
		let arg = E.id arg in
		match typ with
		| Variable _ | Self _ -> E.app [E.gt_fx arg; inh]
		| _ ->
		    match env.trait "foldl" typ with
		    | None   -> inh
		    | Some e -> E.app [e; inh; arg]
	      )
              (E.id env.inh)
	      constr.args
	end
       )
    )