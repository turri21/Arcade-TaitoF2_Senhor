#ifndef FILE_SEARCH_H
#define FILE_SEARCH_H

#include <string>
#include <vector>
#include <filesystem>
#include <unordered_map>
#include "miniz.h"

/**
 * Class for searching and loading files from various paths.
 * Supports searching in directories and inside zip files.
 * Search is performed in the order paths were added.
 */
class FileSearch {
public:
    // Constructor
    FileSearch();
    
    // Destructor - clean up cached zip files
    ~FileSearch();
    
    /**
     * Add a path to the search list
     * @param path Path to a directory or zip file
     * @return true if path exists and was added
     */
    bool addSearchPath(const std::string& path);
    
    /**
     * Load a file into the provided buffer
     * @param filename Name of the file to locate
     * @param buffer Vector to store the file contents
     * @return true if file was found and loaded
     */
    bool loadFile(const std::string& filename, std::vector<uint8_t>& buffer);
    
    /**
     * Clear all search paths
     */
    void clearSearchPaths();

private:
    // Structure to hold opened zip archive information
    struct ZipInfo {
        mz_zip_archive archive;
        bool valid;
        
        ZipInfo() : valid(false) {
            mz_zip_zero_struct(&archive);
        }
        
        ~ZipInfo() {
            if (valid) {
                mz_zip_reader_end(&archive);
            }
        }
    };

    // Enum to track search path type
    enum class PathType {
        Directory,
        ZipFile
    };
    
    // Structure to track search paths in order
    struct SearchPath {
        std::string path;
        PathType type;
    };
    
    // List of search paths in the order they were added
    std::vector<SearchPath> m_searchPaths;
    
    // Map of zip file paths to their archive objects
    std::unordered_map<std::string, ZipInfo*> m_zipFiles;
    
    // Try to load file from a directory
    bool loadFromDirectory(const std::string& dirPath, const std::string& filename, std::vector<uint8_t>& buffer);
    
    // Try to load file from a zip archive
    bool loadFromZip(const std::string& zipPath, const std::string& filename, std::vector<uint8_t>& buffer);
};

// Global FileSearch instance that can be used throughout the application
extern FileSearch g_fs;

#endif // FILE_SEARCH_H