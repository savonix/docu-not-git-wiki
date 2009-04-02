Wiki::Plugin.define 'engine/raw' do
  Wiki::Engine.create(:raw, :priority => 5, :layout => false) do
    accepts {|page| true }
    output  {|context| context.page.content }
    mime    {|page| page.mime }
  end
end
