#ifndef CS_COMBINEGADGET_H
#define CS_COMBINEGADGET_H

#include "Gadget.h"
#include "hoNDArray.h"
#include "CS_LAB_export.h"

#include <ismrmrd.h>
#include <complex>

namespace Gadgetron{
  
  class  EXPORTCSLAB CS_CombineGadget : public Gadget2<ISMRMRD::ImageHeader, hoNDArray< std::complex<float> > >
    {
    public:
      CS_CombineGadget();
      virtual ~CS_CombineGadget();

	  int process_config(ACE_Message_Block* mb);
      
    protected:
      virtual int process( GadgetContainerMessage<ISMRMRD::ImageHeader>* m1,  GadgetContainerMessage< hoNDArray< std::complex<float> > >* m2);   

	  // combine mode
	  int combine_mode_;

	  // scaling factor
	  double scale_;

	  // offset factor
	  double offset_;

	  // repetition averaging flag
	  bool rep_avg_;

	  // array dimensions
	  std::vector<size_t> dimensions_;

    };
}

#endif //CS_COMBINEGADGET_H
