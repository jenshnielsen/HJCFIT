/***********************
    DCProgs computes missed-events likelihood as described in
    Hawkes, Jalali and Colquhoun (1990, 1992)

    Copyright (C) 2013  University College London

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
************************/
%{

  namespace {
    DCProgs::t_Burst convert_pyburst(PyObject *_burst) {
      using namespace DCProgs;
      if(not PySequence_Check(_burst))
        throw errors::PythonTypeError("Expected a sequence on input.");
      t_Burst result;
      Object<> py_iterator = steal_ref(PyObject_GetIter(_burst));
      if(not py_iterator) throw errors::PythonErrorAlreadyThrown();
      while(Object<> item = steal_ref(PyIter_Next(~py_iterator))) {
          if(PyFloat_Check(~item)) 
            result.emplace_back(static_cast<t_real>(PyFloat_AS_DOUBLE(~item)));
#         ifndef DCPROGS_PYTHON3
            else if(PyInt_Check(~item))
              result.emplace_back(static_cast<t_real>(PyInt_AS_LONG(~item)));
#         endif
          else if(PyLong_Check(~item))
            result.emplace_back(static_cast<t_real>(PyLong_AsDouble(~item)));
          else if(PyArray_CheckScalar(~item))  {
            result.push_back(0);
            PyArray_CastScalarToCtype(~item, static_cast<void*>(&result.back()), 
                                      PyArray_DescrFromType(numpy::type<t_real>::value));
            if(PyErr_Occurred()) throw errors::PythonErrorAlreadyThrown();
          } else throw errors::PythonTypeError("Unexpected type in burst.");
      }
      if(PyErr_Occurred()) throw errors::PythonErrorAlreadyThrown();
      return result;
    }
    DCProgs::t_Bursts convert_pybursts(PyObject *_bursts) {
      using namespace DCProgs;
      if(not PySequence_Check(_bursts))
        throw errors::PythonTypeError("Expected a sequence on input.");
      t_Bursts result;
      Object<> py_iterator = steal_ref(PyObject_GetIter(_bursts));
      if(not py_iterator) throw errors::PythonErrorAlreadyThrown();
      while(Object<> item = steal_ref(PyIter_Next(~py_iterator))) {
        if(not PySequence_Check(~item))
          throw errors::PythonTypeError("Expected a sequence of sequences on input.");

        t_Burst burst = convert_pyburst(~item);
        if(burst.size() == 0) continue;
        if(burst.size() % 2 != 1)  
          throw errors::PythonValueError("Each burst must have an odd number of intervals.");
        result.emplace_back(std::move(burst));
      }
  
      if(PyErr_Occurred()) throw errors::PythonErrorAlreadyThrown();
      return result;
    }
  }
%}

%feature("autodoc", "Creates a functor for optimizing the likelihood.\n\n"
         "This functor can as input a :math:`\\mathcal{Q}`-matrix and returns the resulting\n"
         "likelihood. The root finding process is performed by :py:func:`find_roots`. Most of the\n"
         "arguments to initialize this functor are parameters for that process.\n\n"
         ".. attribute:: nopen\n\n"
         "   Number of open states. Should be strictly positive.\n\n"
         ".. attribute:: tau\n\n"
         "   Maximum length of missed events. Should be positive.\n\n"
         ".. attribute:: tcritical\n\n"
         "   :math:`t_{\\mathrm{crit}}` for CHS vectors. If negative, ``None``, or ``NaN``, \n"
         "   then the initial and final states are the equilibrium occupancies.\n\n"
         ".. attribute:: nmax\n\n"
         "  The exact missed-events likelihood will be computed for \n"
         "  :math:`t < n_{\mathrm{max}}\tau`.\n\n"
         ".. attribute:: xtol \n\n"
         "   Tolerance criteria when computing roots via :py:func:`likelihood.brentq`.\n\n"
         ".. attribute:: rtol\n\n"
         "   Tolerance criteria when computing roots via :py:func:`likelihood.brentq`.\n\n"
         ".. attribute:: itermax\n\n"
         "   Maximum number of iterations when computing roots via :py:func:`likelihood.brentq`.\n"
         ".. attribute:: lower_bound\n\n"
         "   Lower bound bracketing all roots. If None or NaN, then the lower bound will be \n"
         "   computed during calls by :py:func:`~dcprogs.likelihood.find_lower_bound_for_root`\n\n"
         ".. attribute:: upper_bound\n\n"
         "   Upper bound bracketing all roots. If None or NaN, then the upper bound will be \n"
         "   computed during calls by :py:func:`~dcprogs.likelihood.find_upper_bound_for_root`\n\n")
         Log10Likelihood;

// The following makes it possible to use keyword arguments in the constructor.
%feature("shadow") Log10Likelihood::Log10Likelihood %{
  def __init__( self, bursts, nopen, tau, tcritical=None, nmax=3, xtol=1e-10, rtol=1e-10,
                itermax=100, lower_bound=None, upper_bound=None ):
    """ Initializes the missed-events likelihood. 

        :param bursts:
           A sequence of bursts. Each burst is a sequence of open and shut intervals. 
           There should always be an odd number of intervals. And the first interval 
           is open by default.
        :param integer nopen:
           Number of open states. Should be strictly positive.
        :param float tau:
           Maximum length of missed events. Should be positive.
        :param float tcritical:
           :math:`t_{\mathrm{crit}}` for CHS vectors. If None, then the initial and final states
           are the equilibrium occupancies.
        :param integer nmax:
           The exact missed-events likelihood will be computed for 
           :math:`t < n_{\matrm{max}}\tau`.
        :param float xtol:
           Tolerance criteria when computing roots via :meth:`likelihood.brentq`
        :param float rtol:
           Tolerance criteria when computing roots via :meth:`likelihood.brentq`.
        :param interger itermax:
           Maximum number of iterations when computing roots via :meth:`likelihood.brentq`.
        :param float lower_bound:
           Lower bound for *all* roots. Defaults to None, in which the case the lower bound is
           computed from :py:func:`find_lower_bound_for_roots`.
        :param float upper_bound:
           Upper bound for *all* roots. Defaults to None, in which the case the upper bound is
           computed from :py:func:`find_upper_bound_for_roots`.
    """
    from numpy import NaN
    if lower_bound is None: lower_bound = NaN
    if upper_bound is None: upper_bound = NaN
    if tcritical is None: tcritical = -1e0
    
    this = $action( bursts, nopen, tau, tcritical, nmax, xtol, rtol, itermax, lower_bound,
                    upper_bound )
    try: self.this.append(this)
    except: self.this = this
%}

%feature("autodoc", "Computes the :math:`log_{10}`-likelihood for the input Q-matrix\n\n"
         ":param matrix:\n"
         "   Can be either a square numpy array  or a :py:class:`QMatrix` object. In the first\n"
         "   case, the number of open states is set to attribute `nopen`.\n\n")
         Log10Likelihood::operator()(QMatrix const &_Q) const;
%feature("autodoc", "Computes the :math:`log_{10}`-likelihood for each individual burst\n\n"
         "The sum over the return of this function is the return of :py:meth:`__call__`.\n"
         "This is merely a convenience function if one wants the likelihood associate with\n"
         "each burst\n\n"
         ":param matrix:\n"
         "   Can be either a square numpy array  or a :py:class:`QMatrix` object. In the first\n"
         "   case, the number of open states is set to attribute `nopen`.\n\n"
         ":return:\n\n"
         "   A numpy array where each component contains the :math:`log_{10}` likelihood of a\n"
         "   single burst.\n")
         Log10Likelihood::vector(QMatrix const &_Q) const;
%feature("autodoc", "Returns the nth burst.\n") Log10Likelihood::__getitem__;
%feature("autodoc", "Sets the nth burst.\n\n"
         ":param index:\n"
         "   Index to the burst that should be changed.\n"
         ":param value:\n"
         "   A list of time intervals with an odd number of components, in seconds.\n")
         Log10Likelihood::__setitem__;
%feature("autodoc", "Deletes the nth burst.\n") Log10Likelihood::__delitem__;
%feature("autodoc", "Number of bursts.\n") Log10Likelihood::__len__;
%feature("autodoc", "Inserts a burst at given index.\n") Log10Likelihood::insert;

        
class Log10Likelihood {
  public:
    //! Number of open states.
    DCProgs::t_uint nopen;
    //! Max length of missed events
    DCProgs::t_real tau;

    // Tells SWIG how to convert tcritical, since it can be negative or NaN or None.
    %typemap(in) DCProgs::t_real tcritical { 
      using namespace DCProgs;
      if($input == Py_None) $1 = quiet_nan;
      else try {
        $1 = convert_to_real($input); 
        if($1 <= 0) $1 = quiet_nan;
      } DCPROGS_CATCH(SWIG_fail);
    }
    %typemap(out) DCProgs::t_real tcritical { 
      if(DCPROGS_ISNAN($1) or $1 <= 0) {
        $result = Py_None;
        Py_INCREF(Py_None);
      } else try { $result = convert_real_to_python($1, $self); }
      DCPROGS_CATCH(SWIG_fail);
    }
    //! \brief tcrit. 
    //! \detail If negative or null, will use equilibrium occupancies rather than CHS occupancies.
    DCProgs::t_real tcritical;
    //! Number of intervals for which to compute exact result.
    DCProgs::t_uint nmax;
    //! Tolerance for root finding.
    DCProgs::t_real xtol;
    //! Tolerance for root finding.
    DCProgs::t_real rtol;
    //! Maximum number of iterations for root finding.
    DCProgs::t_uint itermax;

    // Tells SWIG how to convert upper and lower bounds, since it can be NaN or None.
    %typemap(in) DCProgs::t_real lower_bound { 
      using namespace DCProgs;
      if($input == Py_None) $1 = quiet_nan;
      else try {
        $1 = convert_to_real($input); 
      } DCPROGS_CATCH(SWIG_fail);
    }
    %typemap(out) DCProgs::t_real lower_bound { 
      if(DCPROGS_ISNAN($1)) {
        $result = Py_None;
        Py_INCREF(Py_None);
      } else try { $result = convert_real_to_python($1, $self); }
      DCPROGS_CATCH(SWIG_fail);
    }
    %clear DCProgs::t_real tcritical;
    //! Lower bound bracketing all roots.
    DCProgs::t_real lower_bound;
    %clear DCProgs::t_real lower_bound;
    %typemap(in) DCProgs::t_real upper_bound { 
      using namespace DCProgs;
      if($input == Py_None) $1 = quiet_nan;
      else try {
        $1 = convert_to_real($input); 
      } DCPROGS_CATCH(SWIG_fail);
    }
    %typemap(out) DCProgs::t_real upper_bound { 
      if(DCPROGS_ISNAN($1)) {
        $result = Py_None;
        Py_INCREF(Py_None);
      } else try { $result = convert_real_to_python($1, $self); }
      DCPROGS_CATCH(SWIG_fail);
    }
    //! Upper bound bracketing all roots.
    DCProgs::t_real upper_bound;
    %clear DCProgs::t_real upper_bound;

    // The $self argument below is quite important. It tells SWIG that the memory for the matrix is
    // owned by c++, and that the c++ object should stay alive as long as the matrix lives in python.
    %typemap(out) DCProgs::t_Burst & { 
      try {
        Eigen::Map<DCProgs::t_rvector> map(result->data(), result->size());
        $result = DCProgs::numpy::wrap_to_numpy(map, $self); 
      } DCPROGS_CATCH(SWIG_fail);
    }
    // Constructor
    // This is overriden twice: 
    //   - first in c++ so as to convert bursts.
    //   - then in python, so we can use keyword arguments
    //     This is done above in the feature("shadow") bit
    %extend {
      Log10Likelihood   ( PyObject *_bursts, DCProgs::t_uint _nopen,
                          DCProgs::t_real _tau, DCProgs::t_real _tcritical,
                          DCProgs::t_uint _nmax, DCProgs::t_real _xtol,
                          DCProgs::t_real _rtol, DCProgs::t_uint _itermax,
                          DCProgs::t_real _lower_bound, DCProgs::t_real _upper_bound )  {
        using namespace DCProgs;
        return new Log10Likelihood( convert_pybursts(_bursts), _nopen, _tau, _tcritical,
                                    _nmax, _xtol, _rtol, _itermax, _lower_bound, _upper_bound );
      }
    }

    %extend {
      DCProgs::t_Burst & __getitem__(int i) {
        using namespace DCProgs;
        if(i < 0) i += $self->bursts.size();
        if(i < 0 or static_cast<t_Bursts::size_type>(i) >= $self->bursts.size())
          throw errors::Index("Index to burst is out of range.");
        return $self->bursts[i];
      }
      void insert(int i, PyObject* _burst) {
        using namespace DCProgs;
        if(i < 0) i += $self->bursts.size();
        if(i < 0 or static_cast<t_Bursts::size_type>(i) >= $self->bursts.size())
          throw errors::Index("Index to burst is out of range.");
        t_Burst burst = convert_pyburst(_burst);
        if(burst.size() == 0) return;
        if(burst.size() % 2 != 1)  
          throw errors::PythonValueError("Each burst must have an odd number of intervals.");
        $self->bursts.insert($self->bursts.begin() + i, burst);
      }
      void __setitem__(int i, PyObject* _burst) {
        using namespace DCProgs;
        if(i < 0) i += $self->bursts.size();
        if(i < 0 or static_cast<t_Bursts::size_type>(i) >= $self->bursts.size())
          throw errors::Index("Index to burst is out of range.");
        t_Burst burst = convert_pyburst(_burst);
        if(burst.size() == 0) return;
        if(burst.size() % 2 != 1)  
          throw errors::PythonValueError("Each burst must have an odd number of intervals.");
        $self->bursts[i] = std::move(burst);
      }
      PyObject* __delitem__(int i) {
        using namespace DCProgs;
        if(i < 0) i += $self->bursts.size();
        if(i < 0 or static_cast<t_Bursts::size_type>(i) >= $self->bursts.size())
          throw errors::Index("Index to burst is out of range.");
        t_Burst out = *$self->bursts.erase($self->bursts.begin() + i);
        Eigen::Map<t_rvector> map(out.data(), out.size());
        return numpy::wrap_to_numpy(map);
      }
      int __len__() { return $self->bursts.size(); }
      void append(PyObject* _in) {
        using namespace DCProgs;
        
        t_Burst burst = convert_pyburst(_in);
        if(burst.size() == 0) return;
        if(burst.size() % 2 != 1)  
          throw errors::PythonValueError("Each burst must have an odd number of intervals.");
        $self->bursts.emplace_back(std::move(burst));
      }
      PyObject* __str__() {
        std::ostringstream sstr; sstr << *($self);
        return PyString_FromString(sstr.str().c_str());
      }
      PyObject* __repr__() {
        std::ostringstream sstr; sstr << *($self);
        return PyString_FromString(sstr.str().c_str());
      }
    }
   
    %extend {
      //! Computes likelihood for each burst in separate value.
      DCProgs::t_rvector vector(PyObject* _Q) const {
        return $self->vector(DCProgs::numpy::map_to_rmatrix(_Q));
      }
      DCProgs::t_real operator()(PyObject* _Q) const {
        return $self->operator()(DCProgs::numpy::map_to_rmatrix(_Q));
      }
    }
    //! Computes likelihood for each burst in separate value.
    DCProgs::t_rvector vector(QMatrix const &_Q) const;
    //! Log-likelihood 
    DCProgs::t_real operator()(QMatrix const &_Q) const;
};
