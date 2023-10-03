require 'spec_helper'

module SoftwareVersion
  describe Version do
    it 'check version 4' do
      a = Version.new('4.1.2-29.el6')
      b = Version.new('4.1.2-15.el6_5')
      expect(a > b).to be true
    end

    it 'check version 5' do
      a = Version.new('2014.1.98-65.1.el6')
      b = Version.new('2013.1.95-65.1.el6_5')
      expect(a > b).to be true
    end

    it 'check version 6' do
      a = Version.new('4.1.1-43.P1.el6.centos')
      b = Version.new('4.1.1-34.P1.el6')
      expect(a > b).to be true
    end

    it 'check version 7' do
      a = Version.new('2.6.32-504.el6')
      b = Version.new('2.6.32-504.12.2.el6')
      expect(a < b).to be true
    end

    it 'check version 8' do
      a = Version.new('5.3p1-104.el6')
      b = Version.new('5.3p1-94.el6')
      expect(a > b).to be true
    end

    it 'check version 9' do
      a = Version.new('7.19.7-37.el6_5.3')
      b = Version.new('7.19.7-37.el6_5')
      expect(a > b).to be true
    end

    it 'check version 15' do
      a = Version.new('3.14.3-23.3.el6_8')
      b = Version.new('3.14.3-23.el6_7')
      expect(a > b).to be_truthy
    end

    context 'Sort file test' do
      before(:all) do
        @version_array = fixture('rpm_version_sort.txt').split("\n")
      end

      @version_array = fixture('rpm_version_sort.txt').split("\n")
      @version_array.each_index do |k|
        it "compare #{@version_array[k]} <= #{@version_array[k + 1]}" do
          next if @version_array[k + 1].nil? || @version_array[k + 1] == ''

          a = Version.new(@version_array[k])
          b = Version.new(@version_array[k + 1])
          expect(a <= b).to be true
        end
      end
    end
  end
end
