# encoding: utf-8
# author: Christoph Hartmann

module Generate
  class CLI < Inspec::BaseCLI
    namespace 'generate'

    # read template directoy
    template_dir = File.join(File.dirname(__FILE__), 'templates')
    Dir.glob(File.join(template_dir, '*')) do |template|
      relative = Pathname.new(template).relative_path_from(Pathname.new(template_dir))

      # register command for the template
      desc "#{relative} NAME", "Scaffolds a new #{relative}"
      option :overwrite, type: :boolean, default: false,
         desc: 'Overwrites existing directory'
      define_method relative.to_s.to_sym do |name|
        generator(relative.to_s, { name: name }, options)
      end
    end

    private

    # 1. iterate over all files
    # 2. read content in erb
    # 3. write to target
    def generator(type, attributes = {}, options = {})
      # path of this script
      dir = File.dirname(__FILE__)
      # look for template directory
      base_dir = File.join(dir, 'templates', type)
      # prepare glob for all subdirectories and files
      template = File.join(base_dir, '**', '{*,.*}')
      # generate target path
      target = Pathname.new(Dir.pwd).join(attributes[:name])
      puts "Generate new #{type} at #{mark_text(target)}"

      # check that the directory does not exist
      if File.exist?(target) && !options['overwrite']
        error "#{mark_text(target)} exists already, use --overwrite"
        exit 1
      end

      # iterate over files and write to target path
      Dir.glob(template) do |file|
        relative = Pathname.new(file).relative_path_from(Pathname.new(base_dir))
        destination = Pathname.new(target).join(relative)

        if File.directory?(file)
          li "Create directory #{mark_text(relative)}"
          FileUtils.mkdir_p(destination)
        elsif File.file?(file)
          li "Generate file #{mark_text(relative)}"
          # read & render content
          content = render(File.read(file), attributes)
          # write file content
          File.write(destination, content)
        else
          puts "ignore #{file}, because its not an file or directoy"
        end
      end
    end

    # This is a render helper to bind hash values to a ERB template
    def render(content, hash)
      # create a new binding class
      cls = Class.new do
        hash.each do |key, value|
          define_method key.to_sym do
            value
          end
        end
        # expose binding
        define_method :bind do
          binding
        end
      end
      ERB.new(content).result(cls.new.bind)
    end
  end

  # register the subcommand to Inspec CLI registry
  Inspec::Plugins::CLI.add_subcommand(Generate::CLI, 'generate', 'generate SUBCOMMAND ...', 'Template commands', {})
end
