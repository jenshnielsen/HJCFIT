#ifndef DCPROGS_ERRORS_H
#define DCPROGS_ERRORS_H
#include "DCProgsConfig.h"
#include <string>
#include <exception>
#include <stdexcept>

namespace DCProgs {

  //! Exceptions of DCprogs
  namespace errors {
    
    //! All explicit DCProgs exception derive from this, for easy catching,
    class Root : public std::exception {};
    //! Math (convergence, domain, etc) error
    class Math : public Root { };
    //! Math error which carries a message.
    class Mass : public Math {
      public:
        Mass(std::string const &_message) noexcept : Math() {
          try { message_ = _message; }
          catch(...) { try { message_ = ""; } catch(...) {} }
        }
        virtual char const * what() const noexcept {
          try { return message_.c_str(); } catch(...) { return ""; }
        }
        virtual ~Mass() noexcept {};
      private:
        std::string message_;
    };

    //! Input error to a math problem
    class Domain : public Math, virtual public std::domain_error {
      public:
        explicit Domain(char const *_message) noexcept : Math(), std::domain_error(_message) {};
        explicit Domain(std::string const &_message) noexcept : Math(), std::domain_error(_message) {};
        virtual char const* what() const noexcept { return this->std::domain_error::what(); }
    };
    //! Matrix is not invertible
    class NotInvertible : public Domain {
      public:
        NotInvertible   (char const *_message) noexcept
                      : Domain(_message), std::domain_error(_message) {};
        NotInvertible   (std::string const &_message) noexcept 
                      : Domain(_message), std::domain_error(_message) {};
    };

    //! Runtime error which carries a message.
    class Runtime : public Root {
      public:
        Runtime(std::string const &_message) noexcept : Root() {
          try { message_ = _message; }
          catch(...) { try { message_ = ""; } catch(...) {} }
        }
        virtual char const * what() const noexcept {
          try { return message_.c_str(); } catch(...) { return ""; }
        }
        virtual ~Runtime() noexcept {};
      private:
        std::string message_;
    };
  }
}
#endif
