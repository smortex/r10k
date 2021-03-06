require 'spec_helper'
require 'r10k/action/puppetfile/install'

describe R10K::Action::Puppetfile::Install do
  let(:default_opts) { { root: "/some/nonexistent/path" } }
  let(:puppetfile) {
    R10K::Puppetfile.new('/some/nonexistent/path',
                         {:moduledir => nil, :puppetfile_path => nil, :force => false})
  }

  def installer(opts = {}, argv = [], settings = {})
    opts = default_opts.merge(opts)
    return described_class.new(opts, argv, settings)
  end

  before(:each) do
    allow(puppetfile).to receive(:load!).and_return(nil)
    allow(R10K::Puppetfile).to receive(:new).
      with("/some/nonexistent/path",
           {:moduledir => nil, :puppetfile_path => nil, :force => false}).
      and_return(puppetfile)
  end

  it_behaves_like "a puppetfile install action"

  describe "installing modules" do
    let(:modules) do
      (1..4).map do |idx|
        R10K::Module::Base.new("author/modname#{idx}", "/some/nonexistent/path/modname#{idx}", {})
      end
    end

    before do
      allow(puppetfile).to receive(:modules).and_return(modules)
      allow(puppetfile).to receive(:modules_by_vcs_cachedir).and_return({none: modules})
    end

    it "syncs each module in the Puppetfile" do
      modules.each { |m| expect(m).to receive(:sync) }

      expect(installer.call).to eq true
    end

    it "returns false if a module failed to install" do
      modules[0..2].each { |m| expect(m).to receive(:sync) }
      expect(modules[3]).to receive(:sync).and_raise

      expect(installer.call).to eq false
    end
  end

  describe "purging" do
    before do
      allow(puppetfile).to receive(:modules).and_return([])
    end

    it "purges the moduledir after installation" do
      mock_cleaner = double("cleaner")
      allow(puppetfile).to receive(:desired_contents).and_return(["root/foo"])
      allow(puppetfile).to receive(:managed_directories).and_return(["root"])
      allow(puppetfile).to receive(:purge_exclusions).and_return(["root/**/**.rb"])

      expect(R10K::Util::Cleaner).to receive(:new).
        with(["root"], ["root/foo"], ["root/**/**.rb"]).
        and_return(mock_cleaner)
      expect(mock_cleaner).to receive(:purge!)

      installer.call
    end
  end

  describe "using custom paths" do
    it "can use a custom puppetfile path" do
      expect(R10K::Puppetfile).to receive(:new).
        with("/some/nonexistent/path",
             {:moduledir => nil, :force => false, puppetfile_path: "/some/other/path/Puppetfile"}).
        and_return(puppetfile)

      installer({puppetfile: "/some/other/path/Puppetfile"}).call
    end

    it "can use a custom moduledir path" do
      expect(R10K::Puppetfile).to receive(:new).
        with("/some/nonexistent/path",
             {:puppetfile_path => nil, :force => false, moduledir: "/some/other/path/site-modules"}).
        and_return(puppetfile)

      installer({moduledir: "/some/other/path/site-modules"}).call
    end
  end

  describe "forcing to overwrite local changes" do
    before do
      allow(puppetfile).to receive(:modules).and_return([])
    end

    it "can use the force overwrite option" do
      subject = described_class.new({root: "/some/nonexistent/path", force: true}, [], {})
      expect(R10K::Puppetfile).to receive(:new).
        with("/some/nonexistent/path", {:moduledir => nil, :puppetfile_path => nil, :force => true}).
        and_return(puppetfile)
      subject.call
    end

  end
end
