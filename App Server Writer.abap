REPORT zwrite_appserver.

CLASS cl_appserver_writer DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS: write IMPORTING
                           iv_filename  TYPE string
                           it_data      TYPE ANY TABLE
                           write_header TYPE abap_bool DEFAULT space
                         EXPORTING
                           ev_message   TYPE string.
ENDCLASS.

CLASS cl_appserver_writer IMPLEMENTATION.
  METHOD write.
    TYPES: BEGIN OF ty_comp_detail,
             name  TYPE abap_compname,
             descr TYPE scrtext_m,
           END OF ty_comp_detail.
    DATA: lo_type_def    TYPE REF TO cl_abap_typedescr.
    DATA: lo_struct_def  TYPE REF TO cl_abap_structdescr.
    DATA: lo_table_def   TYPE REF TO cl_abap_tabledescr.
    DATA: lo_data_def    TYPE REF TO cl_abap_datadescr.
    DATA: lo_element_def TYPE REF TO cl_abap_elemdescr.
    DATA: lt_components  TYPE abap_compdescr_tab.
    DATA: wa_components  LIKE LINE OF lt_components.
    DATA: lv_str         TYPE string.
    DATA: lv_filerow     TYPE string.
    DATA: lv_counter     TYPE i VALUE 0.
    DATA: lw_field_info  TYPE dfies.
    DATA: ls_comp_detail TYPE ty_comp_detail.
    DATA: lt_comp_detail TYPE TABLE OF ty_comp_detail.

    FIELD-SYMBOLS: <row> TYPE any.
    FIELD-SYMBOLS: <field_value> TYPE any.

* Using RTTS to get the runtime type information of the internal table
    lo_type_def  = cl_abap_tabledescr=>describe_by_data( it_data ).
    lo_table_def ?= lo_type_def.
    lo_data_def = lo_table_def->get_table_line_type( ).
    lo_struct_def ?= lo_data_def.
    lt_components = lo_struct_def->components.

    CLEAR: lo_data_def.

* If the WRITE_HEADER is ABAP_TRUE then fetch the label
* of data element associated to each component of the
* line type structure of internal table, if no data element
* is associated then use component name as the header text
    IF write_header EQ abap_true.
      LOOP AT lt_components INTO wa_components.
        lo_data_def = lo_struct_def->get_component_type( wa_components-name ).
        lo_element_def ?= lo_data_def.
        lw_field_info = lo_element_def->get_ddic_field( ).
        ls_comp_detail-name = lw_field_info-rollname.

* Calling FM to get data element text
        CALL FUNCTION 'WCGW_DATA_ELEMENT_TEXT_GET'
          EXPORTING
            i_data_element = lw_field_info-rollname
            i_language     = sy-langu
          IMPORTING
            e_scrtext_m    = ls_comp_detail-descr
          EXCEPTIONS
            error          = 1.
        IF ls_comp_detail-descr IS INITIAL.
          ls_comp_detail-descr = wa_components-name.
        ENDIF.
        APPEND ls_comp_detail TO lt_comp_detail.
        CLEAR: ls_comp_detail.
      ENDLOOP.
    ENDIF.


    OPEN DATASET iv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.
    IF sy-subrc EQ 0.
* Writing header text for each column separated by comma
      IF write_header EQ abap_true.
        LOOP AT lt_comp_detail INTO ls_comp_detail.
          lv_counter = lv_counter + 1.
          IF lv_counter EQ 1.
            lv_filerow = ls_comp_detail-descr.
          ELSE.
            CONCATENATE lv_filerow ',' ls_comp_detail-descr INTO lv_filerow.
          ENDIF.
        ENDLOOP.
        TRANSFER lv_filerow TO iv_filename.
        CLEAR: lv_filerow, lv_counter.
      ENDIF.

* Writing internal table content separated by comma
      LOOP AT it_data ASSIGNING <row>.
        LOOP AT lt_components INTO wa_components.
          lv_counter = lv_counter + 1.
          ASSIGN COMPONENT wa_components-name OF STRUCTURE <row> TO <field_value>.
          IF <field_value> IS ASSIGNED.
            lv_str = <field_value>.
            IF lv_counter EQ 1.
              lv_filerow = lv_str.
            ELSE.
              CONCATENATE lv_filerow ',' lv_str INTO lv_filerow.
            ENDIF.
            UNASSIGN <field_value>.
          ENDIF.
        ENDLOOP.
        TRANSFER lv_filerow TO iv_filename.
        CLEAR: lv_filerow, lv_counter.
      ENDLOOP.
      CLOSE DATASET iv_filename.
      ev_message = 'Success'.
    ELSE.
      ev_message = 'Failure'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


START-OF-SELECTION.
  DATA: lt_data  TYPE STANDARD TABLE OF mara.
  DATA: lv_filename TYPE string.
  DATA: lv_message  TYPE string.

  SELECT * FROM mara INTO TABLE lt_data UP TO 5 ROWS.

  cl_appserver_writer=>write(
    EXPORTING
      iv_filename  = 'D:\usr\sap\testdata.csv'
      it_data      = lt_data
      write_header = abap_true
    IMPORTING
      ev_message   = lv_message
  ).

  WRITE: / lv_message.
