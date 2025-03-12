/*
 * SPDX-FileCopyrightText: 2024 Anton Maurovic <anton@maurovic.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// #define SYNC_ON_HIGH

#define RGB2F(xx) ((xx) & 0b11'000000)
#define RGB2to8(xx) ((RGB2F(xx)) | (RGB2F(xx)>>2) | (RGB2F(xx)>>4) | (RGB2F(xx)>>6))

class MAIN_TB : public BASE_TB {
public:
  bool old_hsync_asserted;
  bool old_vsync_asserted;
  bool log_vsync;
  bool examine_mode;
  bool examine_condition_met;
  bool paused;
  bool hsync_polarity; // true=(high during sync)
  bool vsync_polarity;
  int frame_counter;
  int frame_step_counter;

  MAIN_TB(void) {
    log_vsync = false;
    examine_mode = false;
    examine_condition_met = false;
    paused = false;
    frame_counter = 0;
    old_hsync_asserted = true;
    old_vsync_asserted = true;
    frame_step_counter = -1;
#ifdef SYNC_ON_HIGH
    // Sync on high:
    hsync_polarity = true;
    vsync_polarity = true;
#else
    // Sync on low:
    hsync_polarity = false;
    vsync_polarity = false;
#endif
  }

  ~MAIN_TB() { }

  // virtual bool hsync_asserted(void) { return 0 == m_core->hsync; }
  // virtual bool vsync_asserted(void) { return 0 == m_core->vsync; }
  virtual bool hsync_asserted(void) { return (0 != (m_core->uo_out & 0b1000'0000)) == hsync_polarity; }
  virtual bool vsync_asserted(void) { return (0 != (m_core->uo_out & 0b0000'1000)) == vsync_polarity; }

  virtual bool hsync_started(void) { return (!old_hsync_asserted) &&  hsync_asserted(); }
  virtual bool vsync_started(void) { return (!old_vsync_asserted) &&  vsync_asserted(); }
  virtual bool hsync_stopped(void) { return ( old_hsync_asserted) && !hsync_asserted(); }
  virtual bool vsync_stopped(void) { return ( old_vsync_asserted) && !vsync_asserted(); }

  virtual int r(void) { return ((m_core->uo_out & 0b0000'0001)<<7) | ((m_core->uo_out & 0b0001'0000)<<2); }
  virtual int g(void) { return ((m_core->uo_out & 0b0000'0010)<<6) | ((m_core->uo_out & 0b0010'0000)<<1); }
  virtual int b(void) { return ((m_core->uo_out & 0b0000'0100)<<5) | ((m_core->uo_out & 0b0100'0000)   ); }

  // Scale (for example) 0b10'00'00'00 to 0b10'10'10'10 to make it more full-range:
  virtual int rscaled(void) { return RGB2to8(r()); }
  virtual int gscaled(void) { return RGB2to8(g()); }
  virtual int bscaled(void) { return RGB2to8(b()); }

  virtual void tick(void) {
    // if (paused) return;
    //SMELL: We don't respect 'paused' because it's more of a flag for the caller.
    // I've chosen to do it this way because I want the design itself to be able to
    // signal that it should pause, but leave it up to the simulator to decide
    // when to actually stop simulating.
    //NOTE: These are intentionally inverted, since they track the raw values (not their meaning):
    old_hsync_asserted = hsync_asserted(); //m_core->hsync;
    old_vsync_asserted = vsync_asserted(); //m_core->vsync;
    // printf("uo_out=0x%02X\n",m_core->uo_out);
    BASE_TB::tick();
    if (vsync_stopped()) {
      ++frame_counter;
      if (log_vsync) {
        print_time();
        printf("VSYNC released; starting frame %d.\n", frame_counter);
      }
      if (frame_step_counter != -1) {
        if (--frame_step_counter == 0) {
          // Stop.
          pause(true);
          printf("Finished stepping frame(s); frame_counter=%d\n", frame_counter);
          frame_step_counter = -1;
        }
      }
      if (examine()) {
        pause(true);
        printf("(Examine condition met)\n");
        examine_condition_met = false;
        examine_mode = false; // Disable examine mode. User can turn it back on while we're paused, if they want.
      }
    }
  }

  virtual void reset_ticks(int count) {
    // Assert reset:
    m_core->rst_n = 0;
    // Clock 'count' times:
    while (count-- > 0) tick();
    // Release reset:
    m_core->rst_n = 1;
  }

  virtual void frame_step(int count) {
    frame_step_counter = count;
    pause(false);
  }

  virtual bool examine(void) {
    if (!examine_mode) return false;
    return examine_condition_met;
  }

  virtual bool pause(bool state) {
    bool old = paused;
    paused = state;
    if (old != paused) {
      print_time();
      printf("Simulation will %s; at frame %d\n", paused ? "pause" : "resume", frame_counter);
    }
    return old;
  }

};
