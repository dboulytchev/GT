#load "q_MLast.cmo";;

open Pa_gt.Plugin
open List
open Printf
open MLast
open Ploc 
open Pcaml

let _ =
  register "compare" 
    (fun loc d -> 
       let module H = Helper (struct let loc = loc end) in       
       H.(
	{
          inh_t       = `Poly (T.app (T.id d.name :: map T.var d.type_args), fun x -> T.var x); 
          syn_t       = T.acc [T.id "GT"; T.id "comparison"];
          proper_args = d.type_args; 
          arg_img     = (fun _ -> T.acc [T.id "GT"; T.id "comparison"])
        }, 
        object
	  inherit generator
	  method constr env constr =
	    let gen    = name_generator (map fst constr.args) in
	    let other  = gen#generate "other" in
	    let args   = map (fun a -> a, gen#generate a) (map fst constr.args) in
	    let arg  a = assoc a args in
	    let branch = 
	      fold_left
		(fun acc (b, typ) ->
		  E.app [E.acc [E.id "GT"; E.lid "chain_compare"];
			 acc;
			 E.func 
			   [P.wildcard]
			   (match typ with
			   | Instance (_, _, qname) ->
			       (match env.trait "compare" typ with
			       | None   -> E.acc [E.id "GT"; E.uid "EQ"]
			       | Some e -> 
				   let rec name = function
				   | [n]  -> E.app [e; E.app [E.variant (type_tag n); E.id (arg b)]; E.id b]
				   | _::t -> name t
				   in
				   name qname
			       )
			   | Variable  (_, a) -> E.app [E.gt_fx (E.id b); E.app [E.variant (arg_tag a      ); E.id (arg b)]]
			   | Self      _      -> E.app [E.gt_fx (E.id b); E.app [E.variant (type_tag d.name); E.id (arg b)]]
			   | Arbitrary _      -> E.acc [E.id "GT"; E.uid "EQ"]
			   )
		       ]
		)
		(E.acc [E.id "GT"; E.uid "EQ"])
		constr.args
	    in
	    E.match_e (E.id env.inh) 
              [P.app [P.variant (type_tag d.name);
                      P.app (((if d.is_polyvar then P.variant else P.uid) constr.constr)::(map (fun (_, a) -> P.id a) args))
                     ], VaVal None, branch; 

               P.app [P.variant (type_tag d.name); P.id other], 
	       VaVal None, 
	       E.app [E.acc [E.id "GT"; E.id (if d.is_polyvar then "compare_poly" else "compare_vari")]; 
		      E.id other; 
		      E.gt_x (E.id env.subj)
		     ];

               P.wildcard, VaVal None, E.app [E.id "invalid_arg"; E.str "type error (should not happen)"]
              ]
	end
       )
    )
