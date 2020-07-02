import hwpe_stream_package::*;

package nvdla_package;
    // registers in register file
    parameter int unsigned NVDLA_REG_CSB_WDATA = 0; // 32 bits
    parameter int unsigned NVDLA_REG_CSB_RDATA_ADDR = 1; // 32 bits
    parameter int unsigned NVDLA_REG_CSB_ADDR = 2; // 16 bits
    parameter int unsigned NVDLA_REG_CSB_WRITE_FLAG = 2; // 1 bit 
    parameter int unsigned NVDLA_REG_WAIT_INTR_FLAG = 2; // 1 bit

    typedef struct packed {
        logic clear;
        logic enable;
        logic start;
        logic unsigned [15:0] addr;
        logic unsigned [31:0] wdat;
        logic write;
        logic wait_intr;
    } ctrl_engine_t; 

    typedef struct packed {
        logic csb_ready;
        logic csb_valid;
        logic csb_wr_complete;
        logic intr;
    } flags_engine_t;

    typedef struct packed {
        hwpe_stream_package::ctrl_sourcesink_t csb_sink_ctrl;
    } ctrl_csb_streamer_t;

    typedef struct packed {
        hwpe_stream_package::flags_sourcesink_t csb_sink_flags;
    } flags_csb_streamer_t;

    typedef struct packed {
        hwpe_stream_package::ctrl_sourcesink_t dbb_source_ctrl;
        hwpe_stream_package::ctrl_sourcesink_t dbb_sink_ctrl;
    } ctrl_dbb_streamer_t;

    typedef struct packed {
        hwpe_stream_package::flags_sourcesink_t dbb_source_flags;
        hwpe_stream_package::flags_sourcesink_t dbb_sink_flags;
    } flags_dbb_streamer_t;

    typedef struct packed {
        logic valid;
        logic unsigned [31:0] addr;
        logic unsigned [3:0] len;
        logic unsigned [7:0] id;
    } ctrl_dbb_req_t;

    typedef struct packed {
        logic ready;
    } flags_dbb_req_t;

    typedef struct packed {
        logic ready;
    } ctrl_dbb_res_t;

    typedef struct packed {
        logic valid;
        logic unsigned [7:0] id;
    } flags_dbb_res_t;

    typedef struct packed {
        logic valid;
        logic unsigned [`NVDLA_PRIMARY_MEMIF_WIDTH - 1:0] data;
        logic last;
        logic unsigned [`NVDLA_PRIMARY_MEMIF_WIDTH / 8 - 1:0] strb;
    } ctrl_dbb_wdat_t;

    typedef struct packed {
        logic ready;
    } flags_dbb_wdat_t;

    typedef struct packed {
        logic ready;
    } ctrl_dbb_rdat_t;

    typedef struct packed {
        logic valid;
        logic unsigned [`NVDLA_PRIMARY_MEMIF_WIDTH - 1:0] data;
        logic last;
        logic unsigned [7:0] id;
    } flags_dbb_rdat_t;

    typedef struct packed {
        ctrl_dbb_req_t write_request_ctrl;
        ctrl_dbb_req_t read_request_ctrl;
        ctrl_dbb_wdat_t write_data_ctrl;
        ctrl_dbb_res_t write_response_ctrl;
        ctrl_dbb_rdat_t read_data_ctrl;
    } ctrl_dbb_t;

    typedef struct packed {
        flags_dbb_req_t write_request_flags;
        flags_dbb_req_t read_request_flags;
        flags_dbb_wdat_t write_data_flags;
        flags_dbb_res_t write_response_flags;
        flags_dbb_rdat_t read_data_flags;
    } flags_dbb_t;

    typedef struct packed {
        logic unsigned [15:0] addr;
        logic unsigned [31:0] wdat;
        logic write;
        logic wait_intr;
    } ctrl_fsm_t;

    typedef enum {
        FSM_IDLE,
        FSM_START,
        FSM_CONSUME,
        FSM_WAIT_INTR,
        FSM_WAIT,
        FSM_TERMINATE
    } state_fsm_t;

    typedef enum { 
        FSM_DBB_IDLE,
        FSM_WRITE,
        FSM_WRITE_RESPONSE,
        FSM_READ,
        FSM_WAIT_WRITE,
        FSM_WAIT_READ,
        FSM_DBB_TERMINATE
    } state_dbb_fsm_t;

endpackage // nvdla_package