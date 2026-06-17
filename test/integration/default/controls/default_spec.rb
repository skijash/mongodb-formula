# frozen_string_literal: true

control 'mongodb components' do
  title 'should be installed'

  # describe package('unzip') do
  #   it { should be_installed }
  # end
  # describe group('mongodb') do
  #   it { should exist }
  # end
  # describe user('mongodb') do
  #   it { should exist }
  # end
  describe group('mongos') do
    it { should exist }
  end
  # describe user('mongos') do
  #   it { should exist }
  # end
  describe directory('/var/lib/mongodb') do
    it { should exist }
    its('group') { should eq 'root' }
  end
  # describe directory('/usr/local/mongodb/dbtools-100.0.1') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  # describe file('/usr/local/mongodb/dbtools-100.0.1/bin/mongodump') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  # describe file('/usr/local/mongodb/dbtools-100.0.1/bin/bsondump') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  # end
  describe directory('/tmp/downloads') do
    it { should exist }
  end
  # Both Debian and RHEL now repo-install mongod / mongos as
  # /usr/bin/ binaries; archive-extract paths don't exist anymore.
  # The `mongodb runtime` control below verifies the binaries work.
  describe directory('/var/lib/mongodb/mongod') do
    it { should exist }
  end
  describe file('/usr/lib/systemd/system/mongod.service') do
    it { should exist }
    its('group') { should eq 'root' }
    its('mode') { should cmp '0644' }
  end
  describe directory('/usr/local/mongodb/kafka-1.1.0') do
    it { should exist }
    its('group') { should eq 'root' }
  end
  # describe file('/usr/lib/mongodb/kafka-1.1.0/lib/mongo-kafka-1.1.0-all.jar') do
  #   it { should exist }
  #   its('group') { should eq 'root' }
  #   its('mode') { should cmp '0644' }
  # end
  # v8+ replaces the SysV init with a systemd oneshot that ENABLES THP
  # (required for the new TCMalloc per-CPU caches). Kitchen suites pin
  # mongod to the 8.0 stream, so the active mode here is 'always'.
  describe file('/etc/systemd/system/mongodb-thp.service') do
    thp = '/sys/kernel/mm/transparent_hugepage'
    rh = '/sys/kernel/mm/redhat_transparent_hugepage'
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(%r{echo "always" > #{thp}/enabled}) }
    its('content') { should match(%r{echo "defer\+madvise" > #{thp}/defrag}) }
    # Red Hat alias path must also be wired up; missing it regresses
    # hosts that only expose /sys/kernel/mm/redhat_transparent_hugepage.
    its('content') { should match(%r{echo "always" > #{rh}/enabled}) }
  end
  describe service('mongodb-thp') do
    it { should be_enabled }
  end
  describe file('/sys/kernel/mm/transparent_hugepage/enabled') do
    it { should exist }
    its('group') { should eq 'root' }
    its('content') { should match(/\[always\]/) }
  end
  describe file('/etc/mongodb') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end
  describe file('/etc/mongodb/mongod.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    # its('owner') { should eq 'mongodb' }
    # its('group') { should eq 'mongodb' }
  end
  describe file('/etc/mongodb/mongos.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'mongos' }
    its('group') { should eq 'mongos' }
  end
  describe file('/etc/default/mongod.sh') do
    it { should exist }
    its('mode') { should cmp '0640' }
  end
end

control 'mongodb runtime' do
  title 'should be running and accept reads + writes'

  describe service('mongod') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(27_017) do
    it { should be_listening }
  end

  describe file('/usr/local/bin/mongosh') do
    it { should exist }
  end

  # `mongosh` responds with a version in the 8.0 stream the formula
  # pins via the repo URL. Patch level may drift if the repo publishes
  # newer 8.0.x before we bump defaults.yaml - hence stream match, not
  # exact equality.
  describe command('/usr/local/bin/mongosh --quiet --eval "db.version()"') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/^8\.0\.\d+/) }
  end

  # Round-trip: insert a document, read it back. Each kitchen run starts
  # fresh so no need to clean up between runs.
  mongosh_smoke_js = <<~JS.chomp.tr("\n", ' ')
    db = db.getSiblingDB("inspec_test");
    db.kitchen_smoke.insertOne({name: "ci-write-test"});
    print(db.kitchen_smoke.findOne({name: "ci-write-test"}).name)
  JS

  describe command("/usr/local/bin/mongosh --quiet --eval '#{mongosh_smoke_js}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should include 'ci-write-test' }
  end
end
