import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_engine
(
    // global signals
    input  logic                   clk_i,
    input  logic                   core_clk_i,
    input  logic                   csb_clk_i,
    input  logic                   rst_ni,
    input  logic                   test_mode_i,
    // input dbb stream
    hwpe_stream_intf_stream.sink   dbb_i,
    // output dbb stream
    hwpe_stream_intf_stream.source dbb_o,
    // output csb stream
    hwpe_stream_intf_stream.source csb_o,
    // stream control and flags for dbb
    output ctrl_streamer_t         ctrl_streamer_o,
    input  flags_streamer_t        flags_streamer_i,
    // control channel
    input  ctrl_engine_t           ctrl_i,
    output flags_engine_t          flags_o
);

    ctrl_dbb_t dbb_ctrl;
    flags_dbb_t dbb_flags;
    logic csb2nvdla_valid;
    logic csb2nvdla_ready;
    logic nvdla2csb_valid;

    nvdla_hwpe2dbb hwpe2dbb (
        .clk_i            ( clk_i            ),
        .rst_ni           ( rst_ni           ),
        .test_mode_i      ( test_mode_i      ),
        .clear_i          ( clear_i          ),
        .ctrl_streamer_o  ( ctrl_streamer_o  ),
        .flags_streamer_i ( flags_streamer_i ),
        .ctrl_i           ( dbb_ctrl       ),
        .flags_o          ( dbb_flags      ),
        .dbb_i            ( dbb_i            ),
        .dbb_o            ( dbb_o            )
    );

    NV_nvdla nvdla (
        .dla_core_clk                  ( core_clk_i                             ),
        .dla_csb_clk                   ( csb_clk_i                              ),
        .global_clk_ovr_on             ( 1'b0                                   ),
        .tmc2slcg_disable_clock_gating ( 1'b0                                   ),
        .dla_reset_rstn                ( rst_ni                                 ),
        .direct_reset_                 ( rst_ni                                 ),
        .test_mode                     ( test_mode_i                            ),
        .csb2nvdla_valid               ( csb2nvdla_valid                        ),              
        .csb2nvdla_ready               ( csb2nvdla_ready                        ),
        .csb2nvdla_addr                ( ctrl_i.addr                            ),
        .csb2nvdla_wdat                ( ctrl_i.wdat                            ),
        .csb2nvdla_write               ( ctrl_i.write                           ),
        .csb2nvdla_nposted             ( 1'b0                                   ),
        .nvdla2csb_valid               ( nvdla2csb_valid                        ),
        .nvdla2csb_data                ( csb_o.data                             ),
        .nvdla2csb_wr_complete         ( flags_o.csb_wr_complete                ),
        .nvdla_core2dbb_aw_awvalid     ( dbb_ctrl.write_request_ctrl.valid      ),
        .nvdla_core2dbb_aw_awready     ( dbb_flags.write_request_flags.ready    ),
        .nvdla_core2dbb_aw_awaddr      ( dbb_ctrl.write_request_ctrl.addr       ),
        .nvdla_core2dbb_aw_awid        ( dbb_ctrl.write_request_ctrl.id         ),
        .nvdla_core2dbb_aw_awlen       ( dbb_ctrl.write_request_ctrl.len        ),
        .nvdla_core2dbb_w_wvalid       ( dbb_ctrl.write_data_ctrl.valid         ),
        .nvdla_core2dbb_w_wready       ( dbb_flags.write_data_flags.ready       ),
        .nvdla_core2dbb_w_wdata        ( dbb_ctrl.write_data_ctrl.data          ),
        .nvdla_core2dbb_w_wstrb        ( dbb_ctrl.write_data_ctrl.strb          ),
        .nvdla_core2dbb_w_wlast        ( dbb_ctrl.write_data_ctrl.last          ),
        .nvdla_core2dbb_b_bvalid       ( dbb_flags.write_response_flags.valid   ),
        .nvdla_core2dbb_b_bready       ( dbb_ctrl.write_response_ctrl.ready     ),
        .nvdla_core2dbb_b_bid          ( dbb_flags.write_response_flags.id      ),
        .nvdla_core2dbb_ar_arvalid     ( dbb_ctrl.read_request_ctrl.valid       ),
        .nvdla_core2dbb_ar_arready     ( dbb_flags.read_request_flags.ready     ),
        .nvdla_core2dbb_ar_araddr      ( dbb_ctrl.read_request_ctrl.addr        ),
        .nvdla_core2dbb_ar_arid        ( dbb_ctrl.read_request_ctrl.id          ),
        .nvdla_core2dbb_ar_arlen       ( dbb_ctrl.read_request_ctrl.len         ),
        .nvdla_core2dbb_r_rvalid       ( dbb_flags.read_data_flags.valid        ),
        .nvdla_core2dbb_r_rready       ( dbb_ctrl.read_data_ctrl.ready          ),
        .nvdla_core2dbb_r_rid          ( dbb_flags.read_data_flags.id           ),
        .nvdla_core2dbb_r_rlast        ( dbb_flags.read_data_flags.last         ),
        .nvdla_core2dbb_r_rdata        ( dbb_flags.read_data_flags.data         ),
        .dla_intr                      ( flags_o.intr                           ),
        .nvdla_pwrbus_ram_c_pd         ( 32'b0                                  ),
        .nvdla_pwrbus_ram_ma_pd        ( 32'b0                                  ),
        .nvdla_pwrbus_ram_mb_pd        ( 32'b0                                  ),
        .nvdla_pwrbus_ram_p_pd         ( 32'b0                                  ),
        .nvdla_pwrbus_ram_o_pd         ( 32'b0                                  ),
        .nvdla_pwrbus_ram_a_pd         ( 32'b0                                  )
   );

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : csb2nvdla_data_valid
        if(~rst_ni) begin
            csb2nvdla_valid <= '0;
        end
        else if (ctrl_i.clear) begin
            csb2nvdla_valid <= '0;
        end
        else if (ctrl_i.enable) begin
            if (ctrl_i.start) begin
                csb2nvdla_valid <= '1;
            end
        end
    end

    assign csb_o.valid = nvdla2csb_valid;
    assign flags_o.csb_valid = nvdla2csb_valid;

endmodule // nvdla_engine