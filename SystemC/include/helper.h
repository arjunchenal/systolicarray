
#ifndef HELPER_H
#define HELPER_H

#include <systemc.h>
#include <vector>
#include <fstream>
#include <sstream>
#include <string>
#include <iostream>

template<typename T>
inline std::vector<std::vector<T>> read_matrix(const std::string &filename) {
    std::vector<std::vector<T>> mat;
    std::ifstream infile(filename);
    if (!infile.is_open()) {
        std::cerr << "Error " << filename << std::endl;
        return mat;
    }

    std::string line;
    while (std::getline(infile, line)) {
        if (line.empty() || (!line.empty() && line[0] == '#')) continue;

        std::stringstream ss(line);
        std::vector<T> row;
        long long val;              
        while (ss >> val) {
            row.push_back(T(val));   
        }
        if (!row.empty())
            mat.push_back(std::move(row));
    }
    return mat;
}

inline std::vector<std::vector<int>> read_groups(const std::string& filename) {
    std::vector<std::vector<int>> groups;
    std::ifstream in(filename);
    if (!in.is_open()) {
        std::cerr << "[read_groups] Error: Could not open " << filename << "\n";
        return groups;
    }
    std::string line;
    while (std::getline(in, line)) {
        auto first = line.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) continue;
        auto last  = line.find_last_not_of(" \t\r\n");
        line = line.substr(first, last - first + 1);

        if (line.empty() || line[0] == '#') continue;
        if (line.find('|') != std::string::npos) break; 

        bool has_colon = (line.find(':') != std::string::npos);

        std::vector<int> g;

        if (has_colon) {
            auto pos = line.find(':');
            std::istringstream ss(line.substr(pos + 1));
            int v;
            while (ss >> v) g.push_back(v);
        } else {
            std::istringstream ss(line);
            int v;
            while (ss >> v) g.push_back(v);
        }

        if (!g.empty()) groups.push_back(std::move(g));
    }
    return groups;
}


#endif 
