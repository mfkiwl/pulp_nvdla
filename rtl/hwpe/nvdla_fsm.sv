import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_fsm (
    // global signals
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                test_mode_i,
    input  logic                clear_i,
    // ctrl & flags
    output ctrl_streamer_t      ctrl_streamer_o,
    input  flags_streamer_t     flags_streamer_i,
    output ctrl_engine_t        ctrl_engine_o,
    input  flags_engine_t       flags_engine_i,
    output ctrl_slave_t         ctrl_slave_o,
    input  flags_slave_t        flags_slave_i,
    input  ctrl_regfile_t       reg_file_i,
    input  ctrl_fsm_t           ctrl_i
);

    state_fsm_t curr_state, next_state;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : main_fsm_seq
        if(~rst_ni) begin
            curr_state <= FSM_IDLE;
        end
        else if(clear_i) begin
            curr_state <= FSM_IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always_comb
    begin : main_fsm_comb
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.trans_size  = 1;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.line_stride = '0;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.line_length = 1;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.feat_stride = '0;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.feat_length = 1;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.base_addr   = reg_file_i.hwpe_params[NVDLA_REG_CSB_RDATA_ADDR];
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.feat_roll   = '0;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.loop_outer  = '0;
        ctrl_streamer_o.csb_sink_ctrl.addressgen_ctrl.realign_type = '0;

        // engine
        ctrl_engine_o.clear     = '1;
        ctrl_engine_o.enable    = '1;
        ctrl_engine_o.start     = '0;
        ctrl_engine_o.addr      = ctrl_i.addr
        ctrl_engine_o.wdat      = ctrl_i.wdat;
        ctrl_engine_o.write     = ctrl_i.write;
        ctrl_engine_o.wait_intr = ctrl_i.wait_intr;

        // slave
        ctrl_slave_o.done = '0;
        ctrl_slave_o.evt  = '0;

        // real finite-state machine
        next_state   = curr_state;
        ctrl_streamer_o.csb_sink_ctrl.req_start   = '0;

        case(curr_state)
            FSM_IDLE: begin
                // wait for a start signal
                if(flags_slave_i.start) begin
                    next_state = FSM_START;
                end
            end
            FSM_START: begin
                if(~ctrl_i.wait_intr & ~ctrl_i.write &
                   flags_streamer_i.csb_sink_flags.ready_start) begin
                    next_state  = FSM_CONSUME;
                    ctrl_engine_o.start  = 1'b1;
                    ctrl_engine_o.clear  = 1'b0;
                    ctrl_engine_o.enable = 1'b1;
                    ctrl_streamer_o.csb_sink_ctrl.req_start = 1'b1;
                end
                else if(~ctrl_i.wait_intr & ctrl_i.write) begin
                    next_state  = FSM_CONSUME;
                    ctrl_engine_o.start  = 1'b1;
                    ctrl_engine_o.clear  = 1'b0;
                    ctrl_engine_o.enable = 1'b1;
                end
                else if(ctrl_i.wait_intr)
                    next_state  = FSM_WAIT_INTR;
                    ctrl_engine_o.start  = 1'b1;
                    ctrl_engine_o.clear  = 1'b0;
                    ctrl_engine_o.enable = 1'b1;
                else begin
                    next_state = FSM_WAIT;
                end
            end
            FSM_CONSUME: begin
                ctrl_engine_o.clear  = 1'b0;
                if (ctrl_i.write & flags_engine_i.csb_wr_complete) begin
                    next_state = FSM_TERMINATE;
                end
                if (~ctrl_i.write & flags_engine_i.csb_valid) begin
                    next_state = FSM_TERMINATE;
                end
            end
            FSM_WAIT_INTR: begin
                ctrl_engine_o.clear  = 1'b0;
                if (flags_engine_i.intr) begin
                    next_state = FSM_TERMINATE;
                end
            end
            FSM_WAIT: begin
                // wait for the flags to be ok then go back to load
                ctrl_engine_o.clear  = 1'b0;
                ctrl_engine_o.enable = 1'b0;
                if(~ctrl_i.wait_intr & ~ctrl_i.write &
                   flags_streamer_i.csb_sink_flags.ready_start) begin
                    next_state  = FSM_CONSUME;
                    ctrl_engine_o.start  = 1'b1;
                    ctrl_engine_o.enable = 1'b1;
                    ctrl_streamer_o.csb_sink_ctrl.req_start = 1'b1;
                end
            end
            FSM_TERMINATE: begin
                // wait for the flags to be ok then go back to idle
                ctrl_engine_o.clear  = 1'b0;
                ctrl_engine_o.enable = 1'b0;
                if(~ctrl_i.wait_intr & ~ctrl_i.write & 
                   flags_streamer_i.csb_sink_flags.ready_start) begin
                    next_state = FSM_IDLE;
                    ctrl_slave_o.done = 1'b1;
                end
            end
        endcase // curr_state
    end
endmodule // nvdla_fsm