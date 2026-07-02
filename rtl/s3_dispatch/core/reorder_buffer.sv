`timescale 1ns / 1ps

// Reorder Buffer storage — structural queue with four explicit operations:
//   add    — allocate NEW / SPEC_NEW at write pointer (tail)
//   read   — combinational peek + dispatch state advance at read pointer (body)
//   update — capture EX result (READ/SPEC_READ -> EXECUTED/SPEC_EXEC)
//   clear  — retire slots at commit pointer (head); flush clears all pointers
module reorder_buffer
  import rv_dis_pkg::*;
  import rob_pkg::*;
  import rob_queue_pkg::*;

(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        enable,
  input  logic        flush,

  // --- add (tail allocate) ---
  input  logic            add_en,
  input  logic [1:0]      add_count,
  input  logic [ROB_AW-1:0] add_idx0,
  input  logic [ROB_AW-1:0] add_idx1,
  input  logic            add0_valid,
  input  logic            add1_valid,
  input  logic [ROB_DATA_W:0] add_line0,
  input  logic [ROB_DATA_W:0] add_line1,
  input  gpr_addr_t       add_tag0,
  input  gpr_addr_t       add_tag1,

  // --- read (body dispatch) ---
  input  logic [ROB_AW-1:0] read_idx0,
  input  logic [ROB_AW-1:0] read_idx1,
  output rob_data_t       read_data0,
  output rob_data_t       read_data1,
  output gpr_addr_t       read_tag0,
  output gpr_addr_t       read_tag1,
  input  logic            read_advance0,
  input  logic            read_advance1,
  input  logic [1:0]      read_advance_count,

  // --- update (execution complete) ---
  input  logic            update_en,
  input  logic [ROB_AW-1:0] update_idx,
  input  word_t           update_result,

  // --- clear (commit retire) ---
  input  logic            clear_en,
  input  logic [1:0]      clear_count,
  input  logic [ROB_AW-1:0] clear_idx0,
  input  logic [ROB_AW-1:0] clear_idx1,

  // Exported state — rename search, speculation, TB trace
  output rob_ptr_t        write_ptr,
  output rob_ptr_t        read_ptr,
  output rob_ptr_t        commit_ptr,
  output logic [ROB_DATA_W:0] bank [ROB_WAYS],
  output gpr_addr_t       tag  [ROB_WAYS]
);

  rob_ptr_t write_ptr_q;
  rob_ptr_t read_ptr_q;
  rob_ptr_t commit_ptr_q;

  assign write_ptr  = write_ptr_q;
  assign read_ptr   = read_ptr_q;
  assign commit_ptr = commit_ptr_q;

  assign read_data0 = rob_cache_data_read(bank[read_idx0], '0);
  assign read_data1 = rob_cache_data_read(bank[read_idx1], '0);
  assign read_tag0  = tag[read_idx0];
  assign read_tag1  = tag[read_idx1];

  always_ff @(posedge clk or negedge rst_n) begin
    rob_data_t  data_q;
    rob_state_t next_state;

    if (!rst_n || flush) begin
      write_ptr_q  <= '0;
      read_ptr_q   <= '0;
      commit_ptr_q <= '0;
    end else if (!enable) begin
      // hold
    end else begin

      // read — mark dispatched, advance body pointer
      if (read_advance0) begin
        data_q     = rob_cache_data_read(bank[read_idx0], '0);
        next_state = rob_state_after_dispatch(data_q.state);
        bank[read_idx0] <= rob_cache_pack(
          1'b1, rob_data_update_state(data_q, next_state)
        );
      end
      if (read_advance1) begin
        data_q     = rob_cache_data_read(bank[read_idx1], '0);
        next_state = rob_state_after_dispatch(data_q.state);
        bank[read_idx1] <= rob_cache_pack(
          1'b1, rob_data_update_state(data_q, next_state)
        );
      end
      read_ptr_q <= read_ptr_q + {3'b0, read_advance_count};

      // update — execution result
      if (update_en) begin
        data_q = rob_cache_data_read(bank[update_idx], '0);
        if (rob_complete_valid(data_q.state)) begin
          next_state = rob_state_after_complete(data_q.state);
          bank[update_idx] <= rob_cache_pack(
            1'b1,
            rob_data_update_complete(data_q, next_state, update_result)
          );
        end
      end

      // clear — commit retire, invalidate slot
      if (clear_en) begin
        if (clear_count >= 2'd1)
          bank[clear_idx0] <= rob_cache_pack(1'b0, '0);
        if (clear_count >= 2'd2)
          bank[clear_idx1] <= rob_cache_pack(1'b0, '0);
        commit_ptr_q <= commit_ptr_q + {3'b0, clear_count};
      end

      // add — allocate at tail
      if (add_en) begin
        if (add0_valid) begin
          bank[add_idx0] <= add_line0;
          tag[add_idx0]  <= add_tag0;
        end
        if (add1_valid) begin
          bank[add_idx1] <= add_line1;
          tag[add_idx1]  <= add_tag1;
        end
        write_ptr_q <= write_ptr_q + {3'b0, add_count};
      end
    end
  end

endmodule
