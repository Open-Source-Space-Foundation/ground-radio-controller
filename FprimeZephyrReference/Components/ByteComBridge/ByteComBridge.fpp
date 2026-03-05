module Components {
    @ Component which bridges a Drv.ByteStreamDriver to a Svc.Com
    active component ByteComBridge {

        # COM

        output port comDataOut: Svc.ComDataWithContext
        async input port comDataIn: Svc.ComDataWithContext
        async input port comStatusIn: Fw.SuccessCondition

        @ Port returning ownership of data that came in on comDataIn
        output port comDataReturnOut: Svc.ComDataWithContext

        @ Port receiving back ownership of buffer sent out on comDataOut
        async input port comDataReturnIn: Svc.ComDataWithContext


        # BYTE STREAM

        async input port byteStreamReady: Drv.ByteStreamReady

        async input port byteStreamRecv: Drv.ByteStreamData

        output port byteStreamSend: Drv.ByteStreamSend

        @ Port to send back ownership of data received on byteStreamRecv port
        output port byteStreamRecvReturnOut: Fw.BufferSend


        ##############################################################################
        #### Uncomment the following examples to start customizing your component ####
        ##############################################################################


        ###############################################################################
        # Standard AC Ports: Required for Channels, Events, Commands, and Parameters  #
        ###############################################################################
        @ Port for requesting the current time
        time get port timeCaller

    }
}
