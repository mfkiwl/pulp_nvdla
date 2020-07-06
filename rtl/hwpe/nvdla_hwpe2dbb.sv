import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_hwpe2dbb (
    // global signals
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                test_mode_i,
    // ctrl & flags
    output ctrl_dbb_streamer_t      ctrl_streamer_o,
    input  flags_dbb_streamer_t     flags_streamer_i,
    input  ctrl_dbb_t           ctrl_i,
    output flags_dbb_t          flags_o,
    // input dbb stream
    hwpe_stream_intf_stream.sink   dbb_i,
    // output dbb stream
    hwpe_stream_intf_stream.source dbb_o
);
    localparam MEM_DATA_WIDTH_RATIO = `NVDLA_PRIMARY_MEMIF_WIDTH / 32;

    logic [7:0] id;
    logic unsigned [7:0] r_cnt;
    logic unsigned [7:0] rd_len;
    logic unsigned [7:0] wr_len;
    logic clear;
    logic wr_en;
    logic rd_en;

    state_dbb_fsm_t curr_state, next_state;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : main_dbb_fsm_seq
        if(~rst_ni) begin
            curr_state <= FSM_DBB_IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always_comb
    begin : main_dbb_fsm_comb
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.trans_size   = wr_len;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.line_length  = wr_len;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_stride  = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.realign_type = '0;

        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.trans_size   = rd_len;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.line_stride  = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.line_length  = rd_len;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_stride  = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_length  = 1;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.feat_roll    = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.loop_outer   = '0;
        ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.realign_type = '0;

        // hwpe2dbb flags
        flags_o.write_request_flags.ready = '0;
        flags_o.read_request_flags.ready = '0;
        flags_o.write_response_flags.valid = '0;
        wr_en = '0;
        rd_en = '0;

        // real finite-state machine
        next_state   = curr_state;
        clear        = '1;
        ctrl_streamer_o.dbb_sink_ctrl.req_start   = '0;
        ctrl_streamer_o.dbb_source_ctrl.req_start = '0;

        $display("[NVDLA][DBB] State: %d", curr_state);

        case(curr_state)
            FSM_DBB_IDLE: begin
                // wait for a start signal
                flags_o.write_request_flags.ready = '1;
                flags_o.read_request_flags.ready = '1;
                if(ctrl_i.write_request_ctrl.valid) begin
                    next_state = FSM_WAIT_WRITE;
                    id = ctrl_i.write_request_ctrl.id;
                    ctrl_streamer_o.dbb_sink_ctrl.addressgen_ctrl.base_addr = ctrl_i.write_request_ctrl.addr;
                    $display("[NVDLA][DBB] Serving write request(addr=0x%h, len=%d)", 
                        ctrl_i.write_request_ctrl.addr,
                        wr_len);
                end
                else if (ctrl_i.read_request_ctrl.valid) begin
                    next_state = FSM_WAIT_READ;
                    id = ctrl_i.read_request_ctrl.id;
                    ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.base_addr = ctrl_i.read_request_ctrl.addr;
                    $display("[NVDLA][DBB] Serving read request(addr=0x%h, len=%d)", 
                        ctrl_i.read_request_ctrl.addr,
                        rd_len);
                end
            end
            FSM_WRITE: begin
                clear = '0;
                wr_en = '1;
                if (wr_len == r_cnt) begin
                    $display("[NVDLA][DBB] Write finished.");
                    next_state = FSM_WRITE_RESPONSE;
                end
            end
            FSM_WRITE_RESPONSE: begin
                if(ctrl_i.write_response_ctrl.ready & flags_streamer_i.dbb_sink_flags.ready_start) begin
                    next_state = FSM_DBB_TERMINATE;
                    flags_o.write_response_flags.valid = '1;
                    flags_o.write_response_flags.id = id;
                    $display("[NVDLA][DBB] Write response valid");
                end
            end
            FSM_WAIT_WRITE: begin
                clear = '0;
                if (flags_streamer_i.dbb_sink_flags.ready_start) begin
                    next_state = FSM_WRITE;
                    ctrl_streamer_o.dbb_sink_ctrl.req_start = 1'b1;
                end
            end
            FSM_READ: begin
                clear = '0;
                rd_en = '1;
                if (rd_len == r_cnt) begin
                    $display("[NVDLA][DBB] Read finished");
                    next_state = FSM_DBB_TERMINATE;
                end
            end
            FSM_WAIT_READ: begin
                clear = '0;
                if (flags_streamer_i.dbb_source_flags.ready_start) begin
                    next_state = FSM_READ;
                    ctrl_streamer_o.dbb_source_ctrl.req_start = 1'b1;
                end
            end
            FSM_DBB_TERMINATE: begin
                if (flags_streamer_i.dbb_sink_flags.ready_start & 
                    flags_streamer_i.dbb_source_flags.ready_start) begin
                    $display("[NVDLA][DBB] Operation finished. Going idle...");
                    next_state = FSM_DBB_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            r_cnt <= 0;
        end
        else if(clear) begin
            r_cnt <= 0;
        end
        else if(~wr_en & ~rd_en) begin
            r_cnt <= 0;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            dbb_i.ready <= '0;
            flags_o.read_data_flags.valid <= '0;
        end
        else if(clear) begin
            dbb_i.ready <= '0;
            flags_o.read_data_flags.valid <= '0;
        end
        else begin
            if(rd_en & 
               ctrl_i.read_data_ctrl.ready & 
               ~dbb_i.ready & 
               ~flags_o.read_data_flags.valid) begin
               dbb_i.ready <= '1;
            end
            else if(rd_en & 
                    ctrl_i.read_data_ctrl.ready & 
                    dbb_i.ready & 
                    dbb_i.valid) begin
                dbb_i.ready <= '0;
                flags_o.read_data_flags.data <= dbb_i.data;
                flags_o.read_data_flags.id <= id;
                flags_o.read_data_flags.valid <= '1;
                flags_o.read_data_flags.last <= (r_cnt + 1 >= rd_len);
                r_cnt <= r_cnt + 1;
            end
            else if(ctrl_i.read_data_ctrl.ready &
                    flags_o.read_data_flags.valid) begin
                flags_o.read_data_flags.valid <= '0;
                $display("[NVDLA][DBB] Read data: %h ready %d valid: %d r_cnt %d last %d addr %h", 
                    flags_o.read_data_flags.data, ctrl_i.read_data_ctrl.ready, 
                    flags_o.read_data_flags.valid, r_cnt, flags_o.read_data_flags.last,
                    ctrl_streamer_o.dbb_source_ctrl.addressgen_ctrl.base_addr);
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            flags_o.write_data_flags.ready <= '0;
            dbb_o.valid <= '0;
        end
        else if(clear) begin
            flags_o.write_data_flags.ready <= '0;
            dbb_o.valid <= '0;
        end
        else begin
            if(wr_en & 
               dbb_o.ready & 
               ~flags_o.write_data_flags.ready & 
               ~dbb_o.valid) begin
               flags_o.write_data_flags.ready <= '1;
            end
            else if(wr_en & 
                    dbb_o.ready & 
                    flags_o.write_data_flags.ready & 
                    ctrl_i.write_data_ctrl.valid) begin
                flags_o.write_data_flags.ready <= '0;
                dbb_o.data <= ctrl_i.write_data_ctrl.data;
                dbb_o.strb <= ctrl_i.write_data_ctrl.strb;
                dbb_o.valid <= '1;
            end
            else if(wr_en & 
                    dbb_o.ready &
                    dbb_o.valid) begin
                dbb_o.valid <= '0;
                r_cnt <= r_cnt + 1;
                $display("[NVDLA][DBB] Write data: %h strb %h ready %d valid: %d r_cnt %d last %d", 
                    dbb_o.data, dbb_o.strb, dbb_o.ready, dbb_o.valid, r_cnt, ctrl_i.write_data_ctrl.last);
            end
        end
    end

    assign rd_len = 1;
    assign wr_len = 1;

    // assign flags_o.write_data_flags.ready = wr_en & dbb_o.ready;
    
    // always_comb begin
    //     dbb_o.data = ctrl_i.write_data_ctrl.data;
    //     dbb_o.strb = ctrl_i.write_data_ctrl.strb;
    //     dbb_o.valid = ctrl_i.write_data_ctrl.valid; 
    // end

    // assign dbb_i.ready = rd_en & ctrl_i.read_data_ctrl.ready;

    // always_comb begin
    //     flags_o.read_data_flags.id = id;
    //     flags_o.read_data_flags.data = dbb_i.data; 
    //     flags_o.read_data_flags.last = (r_cnt + 1 >= rd_len);
    //     flags_o.read_data_flags.valid = dbb_i.valid;
    // end
    
endmodule // nvdla_hwpe2dbb