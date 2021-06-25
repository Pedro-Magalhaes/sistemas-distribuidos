local cfg = {}


cfg.matrix = require("matrix-config")

cfg.window = {}
cfg.window.width = 1920 / cfg.matrix.collums
cfg.window.height = 1080 / cfg.matrix.lines

cfg.mqtt = {}

-- não está preparado para alterar o nome, vai impactar o tratamento dos eventos
cfg.mqtt.events = { -- only query topics can start with "q". We check if the string starts with "q" to infer that is a query
  "event1",
  "event2",
  "query-event1",
  "query-event2"
}

cfg.event = {
  timeToReset = 30 -- time in seconds to reset event tables.
}

cfg.agent = {
  ttl = 2* cfg.matrix.lines,
  probability=0.6
}

cfg.query = {
  ttl = 2 * cfg.matrix.lines
}

cfg.window.btn = {
  {width=60, title=cfg.mqtt.events[1], color="green"},
  {width=60, title=cfg.mqtt.events[2], color="blue"},
  {width=60, title=cfg.mqtt.events[3], color="green"},
  {width=60, title=cfg.mqtt.events[4], color="blue"},
}
cfg.window.log = {
  y = 50, -- para ficar logo abaixo dos btns
  x = 20,
  lines=6
}

cfg.log = { path="./logs", baseName="out_log_node_" }

cfg.mqtt.server = {
  ip="pi4.local",
  port=1883,
}

return cfg