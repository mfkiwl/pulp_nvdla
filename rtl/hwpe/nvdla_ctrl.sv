import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_ctrl
#(
    parameter int unsigned N_CORES         = 2,
    parameter int unsigned N_CONTEXT       = 2,
    parameter int unsigned N_IO_REGS       = 8,
    parameter int unsigned ID              = 10
)
(
    // global signals
    input  logic                                  clk_i,
    input  logic                                  rst_ni,
    input  logic                                  test_mode_i,
    output logic                                  clear_o,
    // events
    output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
    // ctrl & flags
    output ctrl_streamer_t                        ctrl_streamer_o,
    input  flags_streamer_t                       flags_streamer_i,
    output ctrl_engine_t                          ctrl_engine_o,
    input  flags_engine_t                         flags_engine_i,
    // periph slave port
    hwpe_ctrl_intf_periph.slave                   periph
);

    ctrl_slave_t   slave_ctrl;
    flags_slave_t  slave_flags;
    ctrl_regfile_t reg_file;

    logic unsigned [15:0] static_reg_csb_addr;
    logic unsigned [31:0] static_reg_csb_wdata;
    logic static_reg_csb_write;
    logic static_reg_csb_wait_intr;

    ctrl_fsm_t fsm_ctrl;

    /* Peripheral slave & register file */
    hwpe_ctrl_slave #(
        .N_CORES        ( N_CORES   ),
        .N_CONTEXT      ( N_CONTEXT ),
        .N_IO_REGS      ( N_IO_REGS ),
        .N_GENERIC_REGS ( 0         ),
        .ID_WIDTH       ( ID        )
    ) i_slave (
        .clk_i    ( clk_i       ),
        .rst_ni   ( rst_ni      ),
        .clear_o  ( clear_o     ),
        .cfg      ( periph      ),
        .ctrl_i   ( slave_ctrl  ),
        .flags_o  ( slave_flags ),
        .reg_file ( reg_file    )
    );
    assign evt_o = slave_flags.evt;

    /* Direct register file mappings */
    assign static_reg_csb_wdata     = reg_file.hwpe_params[NVDLA_REG_CSB_WDATA];
    assign static_reg_csb_addr      = reg_file.hwpe_params[NVDLA_REG_CSB_ADDR][31:16];
    assign static_reg_csb_write     = reg_file.hwpe_params[NVDLA_REG_CSB_WRITE_FLAG][8];
    assign static_reg_csb_wait_intr = reg_file.hwpe_params[NVDLA_REG_WAIT_INTR_FLAG][0];

    /* Main FSM */
    mac_fsm i_fsm (
        .clk_i            ( clk_i              ),
        .rst_ni           ( rst_ni             ),
        .test_mode_i      ( test_mode_i        ),
        .clear_i          ( clear_o            ),
        .ctrl_streamer_o  ( ctrl_streamer_o    ),
        .flags_streamer_i ( flags_streamer_i   ),
        .ctrl_engine_o    ( ctrl_engine_o      ),
        .flags_engine_i   ( flags_engine_i     ),
        .ctrl_slave_o     ( slave_ctrl         ),
        .flags_slave_i    ( slave_flags        ),
        .reg_file_i       ( reg_file           ),
        .ctrl_i           ( fsm_ctrl           )
    );
    always_comb
    begin
        fsm_ctrl.addr      = static_reg_csb_addr[15:0];
        fsm_ctrl.wdat      = static_reg_csb_wdata[31:0];
        fsm_ctrl.write     = static_reg_csb_write;
        fsm_ctrl.wait_intr = static_reg_csb_wait_intr;
    end
endmodule // nvdla_ctrl