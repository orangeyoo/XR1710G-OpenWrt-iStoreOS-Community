const renderA = x => x.linkState=="DOWN";
const renderB = x => x.linkState=="DOWN";
const renderC = x => x.linkState=="DOWN";
const renderD = x => x.linkState=="DOWN";
const renderE = x => x.linkState=="DOWN";
const homeCard = C => { const y = {}; y.portList=C.ports||[]; return y.portList };
const statusCard = _ => { const d = {}, v = { value: [] }; d.portList=_.ports||[],v.value=_.ports||[]; return [d.portList, v.value] };
