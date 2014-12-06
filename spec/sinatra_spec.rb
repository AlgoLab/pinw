require_relative '../main'

describe "#web_interface" do
    include Rack::Test::Methods

    before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}

    before(:all) {
        @server = Server.create({
            name: "server1",
            host: "localhost",
            port: "22",
            password: "password",
            username: "user1"
            })
        @user = User.create({
            nickname: "user",
            password: "password",
            email: "email@example.com"
            })
    }
    after(:each) {
        Job.all.each {|job| job.destroy}
        JobRead.all.each {|reads| reads.destroy}
    }

    def app
        PinW.set(:download_path, PROJECT_BASE_PATH + 'test_temp/downloads/')
    end

    it "does not login user with bad password (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: "badpassword"}
        expect(last_response.header['location']).to eq "http://example.org/?err=1"
    end

    it "login the user (##{__LINE__})" do
        # get '/'
        post '/login', {
            InputUser: @user.nickname, 
            InputPassword: @user.password
        }
        expect(last_response.header['location']).to eq "http://example.org/home"
    end

    it "does not accept new job with bad data (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}
        # InputOrganismUnknown: true, InputGeneNameUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            InputOrganismUnknown: 'true', 
            InputGeneNameUnknown: 'true',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=3"

        # InputOrganismUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            InputOrganismUnknown: 'true',
            InputQuality: 33 
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=3"

        # InputGeneNameUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', { 
            InputGeneNameUnknown: 'true',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=3"

        # InputOrganismUnknown: true, InputGeneName: something, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            InputOrganismUnknown: 'true', 
            InputGeneName: 'asd123asd',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=3"

        # InputOrganism: something, InputGeneNameUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneNameUnknown: 'true',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=3"

        # InputOrganism: something, InputGeneName: something, type: 1 
        # and no reads URL or file => error!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '1',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=8"

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and no reads URL or file => error!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=8"

        # InputOrganism: something, InputGeneName: something, type: 3, InputGeneFile: file
        # and no reads URL or file => error!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '3',
            InputGeneFile: Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/genomic_ok.fasta', "text/plain"),
            InputQuality: 33
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=8"
    end

    it "accept new job with data (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}

        # InputOrganism: something, InputGeneName: something, type: 1, InputGeneFile: file
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '1',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: @user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: @user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"

        # InputOrganismUnknown: true, InputGeneNameUnknown: true, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganismUnknown: 'true', 
            InputGeneNameUnknown: 'true',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com'],
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: @user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"

        # InputOrganism: something, InputGeneName: something, type: 3, InputGeneFile: file
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '3',
            InputGeneFile: Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/genomic_ok.fasta', "text/plain"),
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com'],
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: @user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"

        # InputOrganismUnknown: true, InputGeneNameUnknown: true, type: 3, InputGeneFile: file
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganismUnknown: 'true', 
            InputGeneNameUnknown: 'true',
            type: '3',
            InputGeneFile: Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/genomic_ok.fasta', "text/plain"),
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com'],
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: @user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"
    end

    it "does not accept new job when used exceed jobs quota (##{__LINE__})" do
        local_user = User.create({
            nickname: "local_user",
            password: "password",
            email: "email@example.com",
            max_ql: 1
            })
        post '/login', {InputUser: local_user.nickname, InputPassword: local_user.password}

        # InputOrganism: something, InputGeneName: something, type: 1, InputGeneFile: file
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '1',
            InputQuality: 50,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com'],
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: local_user.id)).not_to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs"

        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '1',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com'],
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=1"
        local_user.destroy
    end

    it "does not accept new job when reads exceed reads quota (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com', 'http://www.goofgle.com', 'http://www.ciafo.com', 'http://www.goosgle.com', 'http://www.cisao.com']
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=9"
    end

    it "does not accept new job when a reads has bad url (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['ht?tp://www.goo??gle..com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=5"
    end

    it "does not accept new job which has invalid organism (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'dalek', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=4"
    end

    it "does not accept new job when server has invalid ID (##{__LINE__})" do
        local_user = User.create({
            nickname: "local_user",
            password: "password",
            email: "email@example.com",
            admin: true,
            max_ql: 1
            })
        post '/login', {InputUser: local_user.nickname, InputPassword: local_user.password}

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputServer: 0,
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: local_user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=10"
        local_user.destroy
    end

    it "does not accept new job when type = 1 and organism and genename are unknown (##{__LINE__})" do
        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}
        # InputOrganismUnknown: true, InputGeneNameUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            InputOrganismUnknown: 'true', 
            InputGeneNameUnknown: 'true',
            InputQuality: 33,
            type: 1,
            InputURLs: ['http://www.google.com', 'http://www.ciao.com']
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=2"
    end

    it "disk full fails (##{__LINE__})" do
        expect(Sys::Filesystem).to receive(:stat).and_raise(PinW::DiskFullError)

        post '/login', {InputUser: @user.nickname, InputPassword: @user.password}
        # InputOrganismUnknown: true, InputGeneNameUnknown: true, and no InputGeneURL
        # or InputGeneFile => error!
        post '/jobs/new', {
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: @user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=6"
    end

    it "user quota limit error (##{__LINE__})" do
        local_user = User.create({
            nickname: "local_user",
            password: "password",
            email: "email@example.com",
            admin: true,
            max_fs: 0.001
            })
        post '/login', {InputUser: local_user.nickname, InputPassword: local_user.password}

        # InputOrganism: something, InputGeneName: something, type: 2, InputGeneURL: url
        # and reads URL or file =>ok!
        post '/jobs/new', {
            InputOrganism: 'human', 
            InputGeneName: 'asd123asd',
            type: '2',
            InputGeneURL: 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta',
            InputQuality: 33,
            InputFiles: [Rack::Test::UploadedFile.new(PROJECT_BASE_PATH + 'spec/test_files/ests.fastq', "text/plain")]
        }
        expect(Job.find_by(user_id: local_user.id)).to eq nil
        expect(last_response.header['location']).to eq "http://example.org/jobs?err=7"
        local_user.destroy
    end

end