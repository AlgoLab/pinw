require 'fileutils'
require_relative '../cron/pinw-dispatch'


settings = YAML.load(File.read(PROJECT_BASE_PATH + 'config/database.yml'))
myDispatch = PinWDispatch.new({
      adapter: settings['test']['adapter'],
      database: PROJECT_BASE_PATH + settings['test']['database'],
      timeout: 30000
}, debug: !!(ENV['PINW_RSPEC_VERBOSE']), force: false, download_path: PROJECT_BASE_PATH + 'test_temp/downloads/')


describe PinWDispatch, "#check_server" do
    before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    
    before(:each) {
        @server = Server.create
    }
    after(:each) {
        @server.destroy
    }

    it "does not use server with active connection (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        time = Time.now
        @server.update({
            name: "server",
            host: "localhost",
            port: "22",
            username: "user1",
            priority: 1,
            check_pid: spid,
            check_lock: time - 10
        })

        result = myDispatch.check_server @server, async: false
        expect(Server.find(@server.id).check_pid).to eq spid
        expect(Server.find(@server.id).check_lock).to eq time - 10
    end

    it "does not use server recently checked (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        time = Time.now
        @server.update({
            name: "server1",
            host: "localhost",
            port: "22",
            username: "user1",
            priority: 1,
            check_last_at: time
        })

        result = myDispatch.check_server @server, async: false
        expect(Server.find(@server.id).check_pid).to eq nil
        expect(Server.find(@server.id).check_last_at).to eq time
    end

    it "does not use misconfigured server (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        time = Time.now
        @server.update({
            name: "server1",
            host: "localhost",
            port: "22",
            username: "user1",
            check_pid: spid,
            check_lock: time - 80
        })

        result = myDispatch.check_server @server, async: false
        expect(Server.find(@server.id).check_pid).to eq nil
        expect(Server.find(@server.id).check_lock).not_to eq time - 80
        expect(Server.find(@server.id).check_last_at).not_to eq time - 80
        expect(Server.find(@server.id).last_check_error).to eq "This server has an invalid configuration!"
    end

    it "does not use misconfigured server (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        time = Time.now
        @server.update({
            name: "server1",
            host: "loc??????alh..ost",
            port: "22",
            password: "password",
            username: "user1",
            check_pid: spid,
            check_lock: time - 80
        })

        result = myDispatch.check_server @server, async: false
        expect(Server.find(@server.id).check_pid).to eq nil
        expect(Server.find(@server.id).check_lock).not_to eq time - 80
        expect(Server.find(@server.id).check_last_at).not_to eq time - 80
        expect(Server.find(@server.id).last_check_error).not_to eq nil
    end

end