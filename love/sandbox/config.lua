local cfg = {}

cfg.window = {}
cfg.window.width = 800
cfg.window.height = 600

cfg.mqtt = {}

cfg.mqtt.events = {
  {topic="event1"},
  {topic="event2"},
}

return cfg