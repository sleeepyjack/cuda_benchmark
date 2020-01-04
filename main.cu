#include "include/cuda_benchmark.h"

#define REPEAT2(x)  x x
#define REPEAT4(x)  REPEAT2(x) REPEAT2(x)
#define REPEAT8(x)  REPEAT4(x) REPEAT4(x)
#define REPEAT16(x) REPEAT8(x) REPEAT8(x)
#define REPEAT32(x) REPEAT16(x) REPEAT16(x)

template <typename data_type>
class add_op
{
public:
  static std::string get_name () { return "add"; }
  __device__ data_type operator() (const data_type &a, const data_type &b) const { return a + b; }
};

template<>
struct add_op<int>
{
  static std::string get_name () { return "add"; }
  __device__ int operator() (const int& a, const int& b) const { int tmp; asm volatile ("add.s32 %0, %1, %2;": "=r"(tmp):"r"(a), "r"(b)); return tmp; }
};

template<>
struct add_op<long long int>
{
  static std::string get_name () { return "add"; }
  __device__ long long int operator()(const long long int& a, const long long int& b) const { long long int tmp; asm volatile ("add.s64 %0, %1, %2;": "=l"(tmp):"l"(a), "l"(b)); return tmp; }
};

template<>
struct add_op<unsigned int>
{
  static std::string get_name () { return "add"; }
  __device__ unsigned int operator()(const unsigned int& a, const unsigned int& b) const { unsigned int tmp; asm volatile ("add.u32 %0, %1, %2;": "=r"(tmp):"r"(a), "r"(b)); return tmp; }
};

template<>
struct add_op<float>
{
  static std::string get_name () { return "add"; }
  __device__ float operator()(const float& a, const float& b) const { float tmp; asm volatile ("add.f32 %0, %1, %2;": "=f"(tmp):"f"(a), "f"(b)); return tmp; }
};

template<>
struct add_op<double>
{
  static std::string get_name () { return "add"; }
  __device__ double operator()(const double& a, const double& b) const { double tmp; asm volatile ("add.f64 %0, %1, %2;": "=d"(tmp):"d"(a), "d"(b)); return tmp; }
};

template <typename data_type>
class div_op
{
public:
  static std::string get_name () { return "div"; }
  __device__ data_type operator() (const data_type &a, const data_type &b) const { return a / b; }
};

template <typename data_type>
class mul_op
{
public:
  static std::string get_name () { return "mul"; }
  __device__ data_type operator() (const data_type &a, const data_type &b) const { return a * b; }
};

template <>
class mul_op<int>
{
public:
  static std::string get_name () { return "mul"; }
  __device__ int operator() (const int &a, const int &b) const { int tmp; asm volatile ("add.s32 %0, %1, %2;" : "=r"(tmp) : "r"(a), "r"(b)); return tmp; }
};

template <typename data_type>
class mad_op
{
public:
  static std::string get_name () { return "mad"; }
  __device__ data_type operator() (const data_type &a, const data_type &b) const { data_type tmp = a; tmp += a * b; return tmp; }
};

template <typename data_type>
class exp_op
{
public:
  static std::string get_name () { return "exp"; }
  __device__ data_type operator() (const data_type &a) const { return std::exp (a); }
};

template <typename data_type>
class fast_exp_op
{
public:
  static std::string get_name () { return "fast exp"; }
  __device__ data_type operator() (const data_type &a) const { return __expf (a); }
};

template <typename data_type>
class sin_op
{
public:
  static std::string get_name () { return "sin"; }
  __device__ data_type operator() (const data_type &a) const { return std::sin (a); }
};

template <typename data_type>
class fast_sin_op
{
public:
  static std::string get_name () { return "fast sin"; }
  __device__ data_type operator() (const data_type &a) const { return __sinf (a); }
};

template <typename data_type>
std::string get_type ();

template <> std::string get_type<int> () { return "int"; }
template <> std::string get_type<float> () { return "float"; }
template <> std::string get_type<double> () { return "double"; }

template <typename data_type, typename operation_type>
void operation_benchmark_1 (cuda_benchmark::controller &controller)
{
  data_type *in {};
  cudaMalloc (&in, sizeof (data_type));
  cudaMemset (in, sizeof (data_type), 0);

  operation_type op;

  controller.benchmark (get_type<data_type> () + " " + operation_type::get_name (), [=] __device__ (cuda_benchmark::state &state)
  {
    data_type a = in[threadIdx.x];

    for (auto _ : state)
      {
        REPEAT32(a = op (a););
      }
    state.set_operations_processed (state.max_iterations () * 32);

    in[0] = a;
  });

  cudaFree (in);
}

template <typename data_type, typename operation_type>
void operation_benchmark_2 (cuda_benchmark::controller &controller)
{
  data_type *in {};
  cudaMalloc (&in, 2 * sizeof (data_type));
  cudaMemset (in, 2 * sizeof (data_type), 0);

  operation_type op;

  controller.benchmark (get_type<data_type> () + " " + operation_type::get_name (), [=] __device__ (cuda_benchmark::state &state)
  {
    data_type a = in[threadIdx.x];
    data_type b = in[threadIdx.x + 1];

    for (auto _ : state)
      {
        REPEAT32(a = op (a, b););
      }
    state.set_operations_processed (state.max_iterations () * 32);

    in[0] = (a + b);
  });

  cudaFree (in);
}

template <template <typename> typename op_type>
void operation_benchmark (cuda_benchmark::controller &controller)
{
  operation_benchmark_2<int, op_type<int>> (controller);
  operation_benchmark_2<float, op_type<float>> (controller);
  operation_benchmark_2<double, op_type<double>> (controller);
}

template <template <typename> typename op_type>
void operation_benchmark_float (cuda_benchmark::controller &controller)
{
  operation_benchmark_1<float, op_type<float>> (controller);
  operation_benchmark_1<double, op_type<double>> (controller);
}

int main ()
{
  cuda_benchmark::controller controller (1024, 1);

  operation_benchmark<add_op> (controller);
  operation_benchmark<div_op> (controller);
  operation_benchmark<mul_op> (controller);
  operation_benchmark<mad_op> (controller);

  operation_benchmark_float<exp_op> (controller);
  operation_benchmark_1<float, fast_exp_op<float>> (controller);

  operation_benchmark_float<sin_op> (controller);
  operation_benchmark_1<float, fast_sin_op<float>> (controller);

  return 0;
}
