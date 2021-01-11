-record(packet,
		{data,
		time,
		millisec,%milli secondi atomici(POSIX),una sorta di id temporale
		sizeEthHeader,
		ethHeader,
		sizeDatagramHeader,
		datagramHeader,
		sizeFragmentHeader,
		fragmentHeader,
		protoPayload,
		sizePayload,
		payload}).

-record(flowId,
		{ipSrc,
		ipDst,
		portSrc,
		portDst,
		protoTrans,
		protoService}).

-record(flowInfo,
		{numberOfPackets,
		sizeBytes,
		start,
		finish}).