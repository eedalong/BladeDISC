transform.sequence failures(propagate) {
^bb1(%arg1: !transform.any_op):
  %fill = transform.structured.match ops{["linalg.fill"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  %matmul = transform.structured.match ops{["linalg.matmul"]} in %arg1 : (!transform.any_op) -> !transform.any_op

  %0:2 = transform.structured.tile_to_forall_op %matmul num_threads [1, 1]
    : (!transform.any_op) -> (!transform.any_op, !transform.any_op)
  transform.structured.fuse_into_containing_op %fill into %0#0
    : (!transform.any_op, !transform.any_op) -> (!transform.any_op, !transform.any_op)

  // first level tile and fuse matmul and fill op.
  %1:3 = transform.structured.fuse %0#1 {tile_sizes = [288, 256, 0], tile_interchange = [0, 1, 2]}
    : (!pdl.operation) -> (!pdl.operation, !pdl.operation, !pdl.operationp)
  // second level tile and fuse matmul and fill op.
  %2:3 = transform.structured.fuse %1#0 {tile_sizes = [6, 16, 0], tile_interchange = [0, 1, 2]}
    : (!pdl.operation) -> (!pdl.operation, !pdl.operation, !pdl.operationp)

  // gemm reduction axis tiling
  %3:2 = transform.structured.tile %2#0 [0, 0, 1] {interchange=[0, 1, 2]}  : (!transform.any_op) -> (!transform.any_op, !transform.any_op)

  // clean up
  %func0 = transform.structured.match ops{["func.func"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.apply_patterns %func0 {canonicalization} : (!transform.any_op) -> (!transform.any_op)
  // fold two extract_slice ops generated by two-level tiling. It's needed to enable following
  // pad and hosit schedule.
  %weight_inner_slice = get_producer_of_operand %3#0[1] : (!transform.any_op) -> !transform.any_op
  transform.disc.fold_producer_extract_slice %weight_inner_slice {max_repeat_num = 2}
    : (!transform.any_op) -> !transform.any_op

  // pad to match the requirement of hardware vector/tensor instruction.
  %4 = transform.structured.pad %3#0 {padding_values=[0.0 : f32, 0.0 : f32, 0.0 : f32], padding_dimensions=[0, 1, 2], pack_paddings=[1, 1, 0], hoist_paddings=[4, 0, 0], transpose_paddings=[[1, 0], [0, 1], [0, 1]]}
    : (!transform.any_op) -> !transform.any_op

  %pad_for_input = get_producer_of_operand %4[0] : (!transform.any_op) -> !transform.any_op
  %pad_for_weight = get_producer_of_operand %4[1] : (!transform.any_op) -> !transform.any_op
  %foreach_op = transform.structured.match ops{["scf.forall"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.cache_read {padded} %pad_for_weight at %foreach_op with tile_levels = [1, 1] tile_sizes = [1, 16] permutation = [2, 0, 1, 3] : (!transform.any_op, !transform.any_op) -> (!transform.any_op)

  %pack_op = transform.structured.match ops{["disc_linalg_ext.multi_level_pack"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.lower_multi_level_pack_to_loop %pack_op
    : (!transform.any_op) -> !transform.any_op

  %func1 = transform.structured.match ops{["func.func"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.apply_patterns %func1 {canonicalization} : (!transform.any_op) -> !transform.any_op

  %func2 = transform.structured.match ops{["func.func"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.structured.vectorize %func2 {vectorize_padding}

  %func3 = transform.structured.match ops{["func.func"]} in %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.apply_patterns %func3 {canonicalization} : (!transform.any_op) -> !transform.any_op

  %arg2 = transform.disc.bufferize %arg1 : (!transform.any_op) -> !transform.any_op
  transform.disc.vector.lower_vectors %arg2 contraction_lowering = outerproduct multireduction_lowering = innerparallel split_transfers = "linalg-copy" transpose_lowering = eltwise
    : (!transform.any_op) -> (!transform.any_op)
}