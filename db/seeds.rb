# encoding: utf-8

# TODO: email
User.create! nickname: 'admin', password: 'admin', email: "admin@local.host", admin: true
User.create! nickname: 'guest', password: 'guest', email: "admin@local.host", enabled: false

Organism.create! name: 'Human', ensembl_id: 'human'


ProcessingState.create! key: 'FETCH_CRON_LOCK', value: nil
ProcessingState.create! key: 'DISPATCH_CRON_LOCK', value: nil
ProcessingState.create! key: 'FETCH_ACTIVE_DOWNLOADS', value: 0
