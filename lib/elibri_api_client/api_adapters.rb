
require 'elibri_api_client/api_adapters/v1'

module Elibri
  class ApiClient

    # Modul zawierajacy adaptery dla poszczegolnych wersji API. Dzieki takiej architekturze
    # dodanie kolejnej wersji API sprowadza sie do utworzenia nowej klasy w tym module, np.
    # Elibri::ApiClient::ApiAdapters::V3
    module ApiAdapters


    end

  end
end
