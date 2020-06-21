import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_hwpe2dbb (
    // global signals
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                test_mode_i,
    input  logic                clear_i,
    // ctrl & flags
    output ctrl_streamer_t      ctrl_streamer_o,
    input  flags_streamer_t     flags_streamer_i,
    input  ctrl_dbb_t           ctrl_i,
    output flags_dbb_t          flags_o
    // input dbb stream
    hwpe_stream_intf_stream.sink   dbb_i,
    // output dbb stream
    hwpe_stream_intf_stream.source dbb_o,
);

    logic [7:0] id;
    unsigned logic [3:0] cnt;

    state_dbb_fsm_t curr_state, next_state;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : main_dbb_fsm_seq
        if(~rst_ni) begin
            curr_state <= FSM_DBB_IDLE;
        end
        else if(clear_i) begin
            curr_state <= FSM_DBB_IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always_comb
    begin : main_dbb_fsm_comb
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.trans_size   = ctrl_i.read_request_ctrl.len;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.line_length  = ctrl_i.read_request_ctrl.len;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_stride  = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.base_addr    = ctrl_i.read_request_ctrl.addr;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.realign_type = '0;

        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.trans_size   = ctrl_i.read_request_ctrl.len;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.line_length  = ctrl_i.read_request_ctrl.len;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_stride  = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.base_addr    = ctrl_i.read_request_ctrl.addr;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.realign_type = '0;

        // hwpe2dbb flags
        flags_o.write_request_flags.ready  = '0;
        flags_o.read_request_flags.ready   = '0;
        flags_o.write_data_flags.ready     = '0;
        // flags_o.write_response_flags.valid = '0;
        // flags_o.read_data_flags.valid      = '0;

        // real finite-state machine
        next_state   = curr_state;
        ctrl_streamer_o.dbb_sink_ctrl.req_start   = '0;
        ctrl_streamer_o.dbb_source_ctrl.req_start = '0;

        case(curr_state)
            FSM_DBB_IDLE: begin
                // wait for a start signal
                if(ctrl_i.write_request_ctrl.valid | ctrl_i.read_request_ctrl.valid) begin
                    next_state = FSM_REQUEST;
                end
            end
            FSM_REQUEST: begin
                cnt = '0;
                flags_o.write_response_flags.valid = '0;
                flags_o.read_data_flags.valid      = '0;
                if (ctrl_i.write_request_ctrl.valid & flags_streamer_i.dbb_sink_flags.ready_start) begin
                    next_state = FSM_WRITE;
                    id = ctrl_i.write_request_ctrl.id;
                    ctrl_streamer_o.dbb_sink_ctrl.req_start   = '1;
                    flags_o.write_request_flags.ready  = '1;
                end
                else if(ctrl_i.read_request_ctrl.valid & flags_streamer_i.dbb_source_flags.ready_start) begin
                    next_state = FSM_READ;
                    id = ctrl_i.read_request_ctrl.id;
                    ctrl_streamer_o.dbb_source_ctrl.req_start = '1;
                    flags_o.read_request_flags.ready  = '1;
                end
            end
            FSM_WRITE: begin
                if (cnt == 0) begin
                    flags_o.write_request_flags.ready  = '1;
                end
                if (dbb_o.ready & ctrl_i.write_data_ctrl.valid) begin
                    if(ctrl_i.write_data_ctrl.last) begin
                        next_state = FSM_WRITE_RESPONSE;
                    end
                    else begin
                        next_state = FSM_WAIT_WRITE;
                    end

                    cnt = cnt + 1;
                    
                    d_o.data  = ctrl_i.write_data_ctrl.data
                    d_o.strb  = ctrl_i.write_data_ctrl.strb;
                    d_o.valid = ctrl_i.write_data_ctrl.valid;
                    flags_o.write_data_flags.ready = '0;
                end
            end
            FSM_WRITE_RESPONSE: begin
                if(ctrl_i.write_response_ctrl.ready & flags_streamer_i.dbb_sink_flags.ready_start) begin
                    next_state = FSM_DBB_TERMINATE;
                    flags_o.write_response_flags.valid = '1;
                    flags_o.write_response_flags.id = id;
                end
            end
            FSM_WAIT_WRITE: begin
                if (flags_streamer_i.dbb_sink_flags.ready_start) begin
                    next_state = FSM_WRITE;
                    ctrl_streamer_o.dbb_sink_ctrl.req_start = '1;
                end
            end
            FSM_READ: begin
                if (cnt == 0) begin
                    flags_o.read_request_flags.ready  = '1;
                    flags_o.read_data_flags.last = '0;
                end
                if (dbb_i.valid & ctrl_i.read_data_ctrl.ready) begin
                    if(cnt == ctrl_i.read_request_ctrl.len - 1) begin
                        next_state = FSM_DBB_TERMINATE;
                        flags_o.read_data_flags.last = '1;
                    end
                    else begin
                        next_state = FSM_WAIT_READ;
                    end

                    cnt = cnt + 1;

                    flags_o.read_data_flags.data = dbb_i.data;
                    flags_o.read_data_flags.id = id;
                    flags_o.read_data_flags.valid = dbb_i.valid;
                end
            end
            FSM_WAIT_READ: begin
                if (flags_streamer_i.dbb_source_flags.ready_start) begin
                    next_state = FSM_WRITE;
                    ctrl_streamer_o.dbb_source_ctrl.req_start = '1;
                end
            end
            FSM_DBB_TERMINATE: begin
                if (flags_streamer_i.dbb_sink_flags.ready_start & flags_streamer_i.dbb_source_flags.ready_start) begin
                    next_state = FSM_DBB_IDLE;
                end
            end
        endcase

    end
    
endmodule // nvdla_hwpe2dbb