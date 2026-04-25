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

        guarded input port byteStreamReady: Drv.ByteStreamReady

        guarded input port byteStreamRecv: Drv.ByteStreamData

        output port byteStreamSend: Drv.ByteStreamSend

        @ Port to send back ownership of data received on byteStreamRecv port
        output port byteStreamRecvReturnOut: Fw.BufferSend

        # INTERNAL

        internal port trySendQueuedData() priority 10

        @ Event port
        event port Log

        @ Text event port
        text event port LogText

        @ Received byte-stream data that does not fit in the internal TX queue
        event ByteStreamBufferFull(
            requested: U32 @< Bytes in the incoming byte-stream buffer
            available: U32 @< Remaining free bytes in the internal TX queue
        ) severity warning high format "Dropped byte-stream data; requested {} bytes but only {} bytes were free"

        @ Sending COM-originated data to the byte-stream side failed
        event ByteStreamSendFailed(
            status: Drv.ByteStreamStatus @< Returned status from byteStreamSend
        ) severity warning high format "Failed to send COM data to byte stream: {}"

        @ COM reported that the last transmission was not successful
        event ComStatusFailed(
            status: Fw.Success @< Returned status from comStatusIn
        ) severity warning high format "COM reported failed transmit status: {}"


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
