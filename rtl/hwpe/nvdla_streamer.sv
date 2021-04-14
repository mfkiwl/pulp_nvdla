import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_streamer
#(
    parameter int unsigned MP = 5, // number of master ports
    parameter int unsigned FD = 2  // FIFO depth
)
(
    // global signals
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   test_mode_i,
    // local enable & clear
    input  logic                   enable_i,
    input  logic                   clear_i,

    // input dbb stream + handshake
    hwpe_stream_intf_stream.source dbb_o,
    // output dbb stream + handshake
    hwpe_stream_intf_stream.sink   dbb_i,
    // output csb stream + handshake
    hwpe_stream_intf_stream.source csb_o,
    // output csb stream + handshake
    hwpe_stream_intf_stream.sink   csb_i,

    // TCDM ports
    hwpe_stream_intf_tcdm.master tcdm [MP-1:0],

    // control channel
    input  ctrl_csb_streamer_t  ctrl_csb_i,
    output flags_csb_streamer_t flags_csb_o,
    input  ctrl_dbb_streamer_t  ctrl_dbb_i,
    output flags_dbb_streamer_t flags_dbb_o
);

    logic dbb_tcdm_fifo_ready, csb_tcdm_fifo_ready;

    hwpe_stream_intf_stream #(
        //.DATA_WIDTH ( 32 ),
        .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH )
    ) dbb_prefifo (
        .clk ( clk_i )
    );

    hwpe_stream_intf_stream #(
        //.DATA_WIDTH ( 32 ),
        .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH )
    ) dbb_postfifo (
        .clk ( clk_i )
    );
    
    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
    ) csb_prefifo (
        .clk ( clk_i )
    );

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
    ) csb_postfifo (
        .clk ( clk_i )
    );

    hwpe_stream_intf_tcdm tcdm_fifo_0 [0:0] (
        .clk ( clk_i )
    );

    hwpe_stream_intf_tcdm tcdm_fifo_1 [0:0] (
        .clk ( clk_i )
    );

    hwpe_stream_intf_tcdm tcdm_fifo_2 [0:0] (
        .clk ( clk_i )
    );

    hwpe_stream_intf_tcdm tcdm_fifo_3 [0:0] (
        .clk ( clk_i )
    );

    // source and sink modules
    hwpe_stream_source #(
        .DATA_WIDTH ( 32 ),
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH ),
        .DECOUPLED  ( 1                          )
    ) i_dbb_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( tcdm_fifo_0                  ), // this syntax is necessary for Verilator as hwpe_stream_source expects an array of interfaces
        .stream             ( dbb_prefifo.source           ),
        .ctrl_i             ( ctrl_dbb_i.dbb_source_ctrl   ),
        .flags_o            ( flags_dbb_o.dbb_source_flags ),
        .tcdm_fifo_ready_o  ( dbb_tcdm_fifo_ready          )
    );

    hwpe_stream_sink #(
        .DATA_WIDTH ( 32 )
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH )
    ) i_dbb_sink (
        .clk_i       ( clk_i                      ),
        .rst_ni      ( rst_ni                     ),
        .test_mode_i ( test_mode_i                ),
        .clear_i     ( clear_i                    ),
        .tcdm        ( tcdm_fifo_1                ), // this syntax is necessary for Verilator as hwpe_stream_source expects an array of interfaces
        .stream      ( dbb_postfifo.sink          ),
        .ctrl_i      ( ctrl_dbb_i.dbb_sink_ctrl   ),
        .flags_o     ( flags_dbb_o.dbb_sink_flags )
    );

    hwpe_stream_sink #(
        .DATA_WIDTH ( 32 )
    ) i_csb_sink (
        .clk_i       ( clk_i                      ),
        .rst_ni      ( rst_ni                     ),
        .test_mode_i ( test_mode_i                ),
        .clear_i     ( clear_i                    ),
        .tcdm        ( tcdm_fifo_2                ), // this syntax is necessary for Verilator as hwpe_stream_source expects an array of interfaces
        .stream      ( csb_postfifo.sink          ),
        .ctrl_i      ( ctrl_csb_i.csb_sink_ctrl   ),
        .flags_o     ( flags_csb_o.csb_sink_flags )
    );

    hwpe_stream_source #(
        .DATA_WIDTH ( 32 ),
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH ),
        .DECOUPLED  ( 1                          )
    ) i_dbb_source (
        .clk_i              ( clk_i                        ),
        .rst_ni             ( rst_ni                       ),
        .test_mode_i        ( test_mode_i                  ),
        .clear_i            ( clear_i                      ),
        .tcdm               ( tcdm_fifo_3                  ), // this syntax is necessary for Verilator as hwpe_stream_source expects an array of interfaces
        .stream             ( csb_prefifo.source           ),
        .ctrl_i             ( ctrl_csb_i.csb_source_ctrl   ),
        .flags_o            ( flags_csb_o.csb_source_flags ),
        .tcdm_fifo_ready_o  ( csb_tcdm_fifo_ready          )
    );

    // TCDM-side FIFOs
    hwpe_stream_tcdm_fifo_load #(
        .FIFO_DEPTH ( 4 )
    ) i_dbb_fifo_load (
        .clk_i       ( clk_i               ),
        .rst_ni      ( rst_ni              ),
        .clear_i     ( clear_i             ),
        .flags_o     (                     ),
        .ready_i     ( dbb_tcdm_fifo_ready ),
        .tcdm_slave  ( tcdm_fifo_0[0]      ),
        .tcdm_master ( tcdm[0]             )
    );

    hwpe_stream_tcdm_fifo_store #(
        .FIFO_DEPTH ( 4 )
    ) i_dbb_tcdm_fifo_store (
        .clk_i       ( clk_i          ),
        .rst_ni      ( rst_ni         ),
        .clear_i     ( clear_i        ),
        .flags_o     (                ),
        .tcdm_slave  ( tcdm_fifo_1[0] ),
        .tcdm_master ( tcdm[1]        )
    );

    hwpe_stream_tcdm_fifo_load #(
        .FIFO_DEPTH ( 4 )
    ) i_csb_fifo_load (
        .clk_i       ( clk_i               ),
        .rst_ni      ( rst_ni              ),
        .clear_i     ( clear_i             ),
        .flags_o     (                     ),
        .ready_i     ( csb_tcdm_fifo_ready ),
        .tcdm_slave  ( tcdm_fifo_2[0]      ),
        .tcdm_master ( tcdm[2]             )
    );

    hwpe_stream_tcdm_fifo_store #(
        .FIFO_DEPTH ( 4 )
    ) i_dbb_tcdm_fifo_store (
        .clk_i       ( clk_i          ),
        .rst_ni      ( rst_ni         ),
        .clear_i     ( clear_i        ),
        .flags_o     (                ),
        .tcdm_slave  ( tcdm_fifo_3[0] ),
        .tcdm_master ( tcdm[3]        )
    );

    // datapath-side FIFOs
    hwpe_stream_fifo #(
        .DATA_WIDTH ( 32 ),
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH ),
        .FIFO_DEPTH ( 2                          ),
        .LATCH_FIFO ( 0                          )
    ) i_dbb_fifo (
        .clk_i   ( clk_i            ),
        .rst_ni  ( rst_ni           ),
        .clear_i ( clear_i          ),
        .push_i  ( dbb_prefifo.sink ),
        .pop_o   ( dbb_o            ),
        .flags_o (                  )
    );

    hwpe_stream_fifo #(
        .DATA_WIDTH ( 32 ),
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH ),
        .FIFO_DEPTH ( 2                          ),
        .LATCH_FIFO ( 0                          )
    ) i_dbb_o_fifo (
        .clk_i   ( clk_i               ),
        .rst_ni  ( rst_ni              ),
        .clear_i ( clear_i             ),
        .push_i  ( dbb_i               ),
        .pop_o   ( dbb_postfifo.source ),
        .flags_o (                     )
    );

    hwpe_stream_fifo #(
        .DATA_WIDTH ( 32 ),
        .FIFO_DEPTH ( 2  ),
        .LATCH_FIFO ( 0  )
    ) i_csb_fifo (
        .clk_i   ( clk_i               ),
        .rst_ni  ( rst_ni              ),
        .clear_i ( clear_i             ),
        .push_i  ( csb_prefifo.sink    ),
        .pop_o   ( csb_o               ),
        .flags_o (                     )
    );

    hwpe_stream_fifo #(
        .DATA_WIDTH ( 32 ),
        .FIFO_DEPTH ( 2 ),
        .LATCH_FIFO ( 0 )
    ) i_csb_o_fifo (
        .clk_i   ( clk_i               ),
        .rst_ni  ( rst_ni              ),
        .clear_i ( clear_i             ),
        .push_i  ( csb_i               ),
        .pop_o   ( csb_postfifo.source ),
        .flags_o (                     )
    );

endmodule // nvdla_streamer